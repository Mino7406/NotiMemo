import {
  HttpError,
  RESULT_SCHEMA,
  buildMessages,
  normalizeResult,
  validateRequest,
} from './classify.js';

const MAX_BODY_BYTES = 4096;
const DEFAULT_MODEL = '@cf/meta/llama-3.3-70b-instruct-fp8-fast';

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function errorResponse(status, code) {
  return json({ error: code }, status);
}

/** Workers AI의 하루 무료 한도(10,000 뉴런) 초과 오류인지 판별한다. */
function isQuotaError(err) {
  const msg = String((err && err.message) || err);
  return msg.includes('4006') || msg.toLowerCase().includes('daily free allocation');
}

async function classify(request, env) {
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
    throw new HttpError(413, 'body_too_large');
  }
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    throw new HttpError(400, 'bad_json');
  }
  const input = validateRequest(body);

  // 짧은 시간 폭주 방지. 기기 id가 없으면 접속 IP로 구분한다.
  if (env.LIMITER) {
    const deviceId = (request.headers.get('X-Device-Id') || '').slice(0, 64);
    const key = deviceId || request.headers.get('CF-Connecting-IP') || 'anonymous';
    const { success } = await env.LIMITER.limit({ key });
    if (!success) throw new HttpError(429, 'rate_limited');
  }

  let result;
  try {
    result = await env.AI.run(env.MODEL || DEFAULT_MODEL, {
      messages: buildMessages(input),
      response_format: { type: 'json_schema', json_schema: RESULT_SCHEMA },
      max_tokens: 200,
    });
  } catch (err) {
    if (isQuotaError(err)) throw new HttpError(429, 'quota_exceeded');
    // JSON 모드를 만족하지 못한 경우 포함. 메모 내용은 로그에 남기지 않는다.
    throw new HttpError(502, 'ai_failed');
  }
  return normalizeResult(result && result.response, input.now);
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    try {
      if (pathname === '/health' && request.method === 'GET') return json({ ok: true });
      if (pathname === '/classify') {
        if (request.method !== 'POST') throw new HttpError(405, 'method_not_allowed');
        return json(await classify(request, env));
      }
      throw new HttpError(404, 'not_found');
    } catch (err) {
      if (err instanceof HttpError) return errorResponse(err.status, err.code);
      return errorResponse(500, 'internal_error');
    }
  },
};
