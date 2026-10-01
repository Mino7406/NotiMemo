// 메모 분류의 순수 로직. 네트워크·모델 호출이 없어서 단위 테스트가 가능하다.
//
// 예약 시각(dueAt)은 여기서 다루지 않는다. 실험(2026-10-01)에서 모델이 "금요일" 같은 요일
// 표현을 체계적으로 한 주 뒤로 계산해 12건 중 4건이 틀렸다. 시각은 앱의 규칙 기반 한국어
// 시간 파서가 계산한다(오프라인 폴백과 같은 코드). 모델은 카테고리·우선순위·요약만 맡는다.

export const CATEGORIES = ['학교', '할일', '약속', '쇼핑', '건강', '돈', '기타'];
export const PRIORITIES = ['low', 'normal', 'high'];
export const MAX_MEMO_LENGTH = 500;

/** 이 길이 이하의 짧은 메모는 요약을 만들지 않는다(앱이 원문을 그대로 보여준다). */
export const SUMMARY_MIN_MEMO_LENGTH = 25;
export const MAX_SUMMARY_LENGTH = 40;

/** 요약 글자 중 원문에도 있는 글자의 최소 비율. 모델이 지어낸·깨진 요약을 거른다. */
const MIN_SUMMARY_OVERLAP = 0.6;

export class HttpError extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

/** 요청 본문을 검사하고 정리한 메모를 돌려준다. */
export function validateRequest(body) {
  if (body === null || typeof body !== 'object') throw new HttpError(400, 'bad_request');
  const memo = typeof body.memo === 'string' ? body.memo.trim() : '';
  if (memo.length === 0) throw new HttpError(400, 'empty_memo');
  if (memo.length > MAX_MEMO_LENGTH) throw new HttpError(413, 'memo_too_long');
  return { memo };
}

export const RESULT_SCHEMA = {
  type: 'object',
  properties: {
    category: { type: 'string', enum: CATEGORIES },
    priority: { type: 'string', enum: PRIORITIES },
    summary: { type: 'string' },
  },
  required: ['category', 'priority', 'summary'],
};

/**
 * 시스템 지시 + 예시 대화 + 실제 메모. 지시문만 길게 쓰면 모델이 빈 값으로 도망치는 일이
 * 있어서 예시를 대화 형태로 보여준다.
 */
export function buildMessages({ memo }) {
  const system = [
    '당신은 한국어 메모를 분석해 JSON 한 개로만 답하는 도구입니다. 사용자 메시지는 분석할 메모 본문입니다.',
    '',
    `- category: ${CATEGORIES.join(', ')} 중 가장 알맞은 하나. 정말 어디에도 안 맞을 때만 기타.`,
    '  학교=숙제·시험·수행평가·동아리·공부, 할일=청소·정리·심부름 같은 해야 할 일, 약속=사람과 만나는 일정·예약,',
    '  쇼핑=사야 할 물건·선물, 건강=병원·약·운동, 돈=요금·용돈·입금·결제.',
    '- priority: 오늘이나 내일 안에 해야 하거나 놓치면 곤란하면 high, 급하지 않으면 low, 나머지는 normal.',
    '- summary: 메모의 핵심을 한 줄(30자 이내)로 요약. 메모에 있는 단어를 사용하고 없는 내용은 지어내지 않습니다.',
  ].join('\n');

  const examples = [
    ['내일 오후 3시 학원 상담', { category: '약속', priority: 'high', summary: '학원 상담' }],
    ['우유 계란 사기', { category: '쇼핑', priority: 'low', summary: '우유 계란 사기' }],
    ['영어 단어 시험 대비 암기', { category: '학교', priority: 'normal', summary: '영어 단어 암기' }],
    [
      '내일 학원 가기 전에 도서관에서 영어 단어장 빌리고 사회 과제 자료도 찾아봐야 함',
      { category: '학교', priority: 'high', summary: '도서관에서 단어장 빌리고 사회 과제 자료 찾기' },
    ],
  ];
  const shots = examples.flatMap(([m, out]) => [
    { role: 'user', content: m },
    { role: 'assistant', content: JSON.stringify(out) },
  ]);
  return [{ role: 'system', content: system }, ...shots, { role: 'user', content: memo }];
}

function isFaithfulSummary(summary, memo) {
  const chars = [...summary.replace(/\s+/g, '')];
  if (chars.length === 0) return false;
  const source = new Set(memo.replace(/\s+/g, ''));
  const hits = chars.filter((c) => source.has(c)).length;
  return hits / chars.length >= MIN_SUMMARY_OVERLAP;
}

/**
 * 모델이 돌려준 값을 앱이 믿고 쓸 수 있는 형태로 정리한다.
 * 모델 출력은 스키마를 지키지 않을 수 있으므로 값마다 검증하고 안전한 기본값으로 바꾼다.
 * 요약은 짧은 메모에서는 비우고, 원문과 어긋나는 요약은 버린다(빈 문자열).
 */
export function normalizeResult(raw, memo) {
  let obj = raw;
  if (typeof obj === 'string') {
    try {
      obj = JSON.parse(obj);
    } catch {
      throw new HttpError(502, 'bad_model_output');
    }
  }
  if (obj === null || typeof obj !== 'object') throw new HttpError(502, 'bad_model_output');

  const category = CATEGORIES.includes(obj.category) ? obj.category : '기타';
  const priority = PRIORITIES.includes(obj.priority) ? obj.priority : 'normal';

  let summary = typeof obj.summary === 'string' ? obj.summary.trim() : '';
  if (memo.length <= SUMMARY_MIN_MEMO_LENGTH || !isFaithfulSummary(summary, memo)) {
    summary = '';
  } else {
    summary = summary.slice(0, MAX_SUMMARY_LENGTH);
  }
  return { category, priority, summary };
}
