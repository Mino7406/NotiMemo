import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import {
  HttpError,
  buildMessages,
  isValidLocalTime,
  normalizeResult,
  validateRequest,
} from '../src/classify.js';

const NOW = '2026-10-01T10:30';

test('isValidLocalTime: 형식과 실제 존재하는 날짜만 통과', () => {
  assert.equal(isValidLocalTime('2026-10-02T15:00'), true);
  assert.equal(isValidLocalTime('2026-02-30T10:00'), false);
  assert.equal(isValidLocalTime('2026-10-02T24:00'), false);
  assert.equal(isValidLocalTime('2026-10-02 15:00'), false);
  assert.equal(isValidLocalTime(''), false);
  assert.equal(isValidLocalTime(null), false);
});

test('validateRequest: 정상 입력은 공백을 정리해 통과', () => {
  assert.deepEqual(validateRequest({ memo: '  우유 사기 ', now: NOW }), {
    memo: '우유 사기',
    now: NOW,
  });
});

test('validateRequest: 잘못된 입력은 상태 코드와 함께 거절', () => {
  const code = (body) => {
    try {
      validateRequest(body);
    } catch (e) {
      return [e.status, e.code];
    }
  };
  assert.deepEqual(code(null), [400, 'bad_request']);
  assert.deepEqual(code({ memo: '   ', now: NOW }), [400, 'empty_memo']);
  assert.deepEqual(code({ memo: 'a'.repeat(501), now: NOW }), [413, 'memo_too_long']);
  assert.deepEqual(code({ memo: 'x', now: '내일' }), [400, 'bad_now']);
});

test('buildMessages: 현재 시각과 메모가 들어가고, 메모는 user 메시지로만 전달', () => {
  const msgs = buildMessages({ memo: '내일 3시 치과', now: NOW });
  assert.equal(msgs[0].role, 'system');
  assert.ok(msgs[0].content.includes(NOW));
  assert.ok(!msgs[0].content.includes('치과'));
  assert.deepEqual(msgs[1], { role: 'user', content: '내일 3시 치과' });
});

test('normalizeResult: 정상 값은 그대로, 미래 dueAt은 유지', () => {
  const r = normalizeResult(
    { category: '약속', priority: 'high', summary: '내일 치과', dueAt: '2026-10-02T15:00' },
    NOW,
  );
  assert.deepEqual(r, {
    category: '약속',
    priority: 'high',
    summary: '내일 치과',
    dueAt: '2026-10-02T15:00',
  });
});

test('normalizeResult: 목록에 없는 값은 안전한 기본값으로', () => {
  const r = normalizeResult(
    { category: '게임', priority: '긴급', summary: 7, dueAt: '' },
    NOW,
  );
  assert.deepEqual(r, { category: '기타', priority: 'normal', summary: '', dueAt: null });
});

test('normalizeResult: 과거·잘못된 dueAt은 null', () => {
  assert.equal(normalizeResult({ dueAt: '2026-10-01T09:00' }, NOW).dueAt, null);
  assert.equal(normalizeResult({ dueAt: NOW }, NOW).dueAt, null);
  assert.equal(normalizeResult({ dueAt: '2026-13-40T99:99' }, NOW).dueAt, null);
});

test('normalizeResult: 문자열 JSON도 처리, 깨진 출력은 502', () => {
  const ok = normalizeResult('{"category":"쇼핑","priority":"low","summary":"우유","dueAt":""}', NOW);
  assert.equal(ok.category, '쇼핑');
  assert.throws(() => normalizeResult('not json', NOW), (e) => e instanceof HttpError && e.status === 502);
  assert.throws(() => normalizeResult(null, NOW), (e) => e.status === 502);
});

test('normalizeResult: summary는 40자로 자른다', () => {
  assert.equal(normalizeResult({ summary: 'ㄱ'.repeat(100) }, NOW).summary.length, 40);
});

// ---- HTTP 처리 ----

function post(path, body, headers = {}) {
  return new Request(`https://x.test${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

const okAi = (response) => ({ run: async () => ({ response }) });

test('POST /classify 성공', async () => {
  const env = {
    AI: okAi({ category: '학교', priority: 'high', summary: '수학 숙제', dueAt: '2026-10-02T09:00' }),
  };
  const res = await worker.fetch(post('/classify', { memo: '내일까지 수학 숙제', now: NOW }), env);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await res.json(), {
    category: '학교',
    priority: 'high',
    summary: '수학 숙제',
    dueAt: '2026-10-02T09:00',
  });
});

test('모델에는 JSON 스키마 응답 형식을 요청한다', async () => {
  let seen;
  const env = {
    MODEL: 'test-model',
    AI: {
      run: async (model, args) => {
        seen = { model, args };
        return { response: { category: '기타', priority: 'normal', summary: 'x', dueAt: '' } };
      },
    },
  };
  await worker.fetch(post('/classify', { memo: 'x', now: NOW }), env);
  assert.equal(seen.model, 'test-model');
  assert.equal(seen.args.response_format.type, 'json_schema');
});

test('잘못된 요청과 경로', async () => {
  const env = { AI: okAi({}) };
  assert.equal((await worker.fetch(post('/classify', '{깨진'), env)).status, 400);
  assert.equal((await worker.fetch(post('/classify', { memo: '', now: NOW }), env)).status, 400);
  assert.equal((await worker.fetch(post('/classify', 'a'.repeat(5000)), env)).status, 413);
  assert.equal((await worker.fetch(new Request('https://x.test/classify'), env)).status, 405);
  assert.equal((await worker.fetch(new Request('https://x.test/nope'), env)).status, 404);
  assert.equal((await worker.fetch(new Request('https://x.test/health'), env)).status, 200);
});

test('Workers AI 일일 한도 초과는 429 quota_exceeded', async () => {
  const env = {
    AI: {
      run: async () => {
        throw new Error('4006: you have used up your daily free allocation of 10,000 neurons');
      },
    },
  };
  const res = await worker.fetch(post('/classify', { memo: 'x', now: NOW }), env);
  assert.equal(res.status, 429);
  assert.deepEqual(await res.json(), { error: 'quota_exceeded' });
});

test('모델 오류(JSON 모드 실패 등)는 502 ai_failed, 내용은 노출하지 않는다', async () => {
  const env = {
    AI: {
      run: async () => {
        throw new Error("JSON Mode couldn't be met: 비밀 메모 내용");
      },
    },
  };
  const res = await worker.fetch(post('/classify', { memo: '비밀 메모 내용', now: NOW }), env);
  assert.equal(res.status, 502);
  const text = await res.text();
  assert.ok(!text.includes('비밀'));
});

test('요청 횟수 제한: 기기 id를 키로 쓰고 초과 시 429', async () => {
  const keys = [];
  const env = {
    AI: okAi({ category: '기타', priority: 'normal', summary: 'x', dueAt: '' }),
    LIMITER: {
      limit: async ({ key }) => {
        keys.push(key);
        return { success: false };
      },
    },
  };
  const res = await worker.fetch(
    post('/classify', { memo: 'x', now: NOW }, { 'X-Device-Id': 'dev-123' }),
    env,
  );
  assert.equal(res.status, 429);
  assert.deepEqual(keys, ['dev-123']);
});

test('LIMITER 바인딩이 없어도 동작한다', async () => {
  const env = { AI: okAi({ category: '기타', priority: 'normal', summary: 'x', dueAt: '' }) };
  const res = await worker.fetch(post('/classify', { memo: 'x', now: NOW }), env);
  assert.equal(res.status, 200);
});
