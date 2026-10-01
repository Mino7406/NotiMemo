import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../src/index.js';
import {
  HttpError,
  buildMessages,
  normalizeResult,
  validateRequest,
} from '../src/classify.js';

const LONG = '내일 학원 가기 전에 도서관에서 영어 단어장 빌리고 사회 과제 자료도 찾아봐야 함';

test('validateRequest: 정상 입력은 공백을 정리해 통과', () => {
  assert.deepEqual(validateRequest({ memo: '  우유 사기 ' }), { memo: '우유 사기' });
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
  assert.deepEqual(code({ memo: '   ' }), [400, 'empty_memo']);
  assert.deepEqual(code({ memo: 5 }), [400, 'empty_memo']);
  assert.deepEqual(code({ memo: 'a'.repeat(501) }), [413, 'memo_too_long']);
});

test('buildMessages: 메모는 마지막 user 메시지로만 전달되고 시스템 지시에는 섞이지 않는다', () => {
  const msgs = buildMessages({ memo: '내일 3시 치과' });
  assert.equal(msgs[0].role, 'system');
  assert.ok(!msgs[0].content.includes('치과'));
  assert.deepEqual(msgs.at(-1), { role: 'user', content: '내일 3시 치과' });
  // 예시는 user/assistant가 번갈아 나오고, assistant 예시는 올바른 JSON이다.
  for (let i = 1; i < msgs.length - 1; i += 2) {
    assert.equal(msgs[i].role, 'user');
    assert.equal(msgs[i + 1].role, 'assistant');
    assert.ok(JSON.parse(msgs[i + 1].content).category);
  }
});

test('normalizeResult: 짧은 메모는 요약을 비운다', () => {
  const r = normalizeResult(
    { category: '약속', priority: 'high', summary: '학원 상담' },
    '내일 오후 3시 학원 상담',
  );
  assert.deepEqual(r, { category: '약속', priority: 'high', summary: '' });
});

test('normalizeResult: 긴 메모는 원문과 겹치는 요약을 남긴다', () => {
  const r = normalizeResult(
    { category: '학교', priority: 'high', summary: '도서관에서 단어장 빌리고 사회 과제 자료 찾기' },
    LONG,
  );
  assert.equal(r.summary, '도서관에서 단어장 빌리고 사회 과제 자료 찾기');
});

test('normalizeResult: 원문과 어긋나는(깨진·지어낸) 요약은 버린다', () => {
  const memo = '수학 문제집 30쪽 풀고 나서 영어 단어도 외우고 과학 숙제 확인하기';
  assert.equal(
    normalizeResult({ category: '학교', priority: 'normal', summary: '수학 30총 팔미' }, memo).summary,
    '',
  );
  assert.equal(
    normalizeResult({ category: '학교', priority: 'normal', summary: 'Buy milk and eggs' }, memo).summary,
    '',
  );
});

test('normalizeResult: 목록에 없는 값은 안전한 기본값으로', () => {
  const r = normalizeResult({ category: '게임', priority: '긴급', summary: 7 }, LONG);
  assert.deepEqual(r, { category: '기타', priority: 'normal', summary: '' });
});

test('normalizeResult: 문자열 JSON도 처리, 깨진 출력은 502', () => {
  const ok = normalizeResult('{"category":"쇼핑","priority":"low","summary":""}', '우유');
  assert.equal(ok.category, '쇼핑');
  assert.throws(() => normalizeResult('not json', 'x'), (e) => e instanceof HttpError && e.status === 502);
  assert.throws(() => normalizeResult(null, 'x'), (e) => e.status === 502);
});

test('normalizeResult: 요약은 40자로 자른다', () => {
  const memo = '가'.repeat(100);
  assert.equal(normalizeResult({ summary: '가'.repeat(80) }, memo).summary.length, 40);
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
const fine = { category: '기타', priority: 'normal', summary: '' };

test('POST /classify 성공', async () => {
  const env = { AI: okAi({ category: '학교', priority: 'high', summary: '' }) };
  const res = await worker.fetch(post('/classify', { memo: '내일까지 수학 숙제' }), env);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(await res.json(), { category: '학교', priority: 'high', summary: '' });
});

test('모델에는 설정한 모델명과 JSON 스키마 응답 형식을 요청한다', async () => {
  let seen;
  const env = {
    MODEL: 'test-model',
    AI: {
      run: async (model, args) => {
        seen = { model, args };
        return { response: fine };
      },
    },
  };
  await worker.fetch(post('/classify', { memo: 'x' }), env);
  assert.equal(seen.model, 'test-model');
  assert.equal(seen.args.response_format.type, 'json_schema');
});

test('잘못된 요청과 경로', async () => {
  const env = { AI: okAi({}) };
  assert.equal((await worker.fetch(post('/classify', '{깨진'), env)).status, 400);
  assert.equal((await worker.fetch(post('/classify', { memo: '' }), env)).status, 400);
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
  const res = await worker.fetch(post('/classify', { memo: 'x' }), env);
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
  const res = await worker.fetch(post('/classify', { memo: '비밀 메모 내용' }), env);
  assert.equal(res.status, 502);
  assert.ok(!(await res.text()).includes('비밀'));
});

test('요청 횟수 제한: 기기 id를 키로 쓰고 초과 시 429', async () => {
  const keys = [];
  const env = {
    AI: okAi(fine),
    LIMITER: {
      limit: async ({ key }) => {
        keys.push(key);
        return { success: false };
      },
    },
  };
  const res = await worker.fetch(post('/classify', { memo: 'x' }, { 'X-Device-Id': 'dev-123' }), env);
  assert.equal(res.status, 429);
  assert.deepEqual(keys, ['dev-123']);
});

test('LIMITER 바인딩이 없어도 동작한다', async () => {
  const res = await worker.fetch(post('/classify', { memo: 'x' }), { AI: okAi(fine) });
  assert.equal(res.status, 200);
});
