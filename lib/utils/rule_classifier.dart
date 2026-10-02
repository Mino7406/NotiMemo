import '../models/memo_analysis.dart';
import '../models/memo_entry.dart';
import 'due_parser.dart';

/// 인터넷·서버 없이 메모를 분류하는 키워드 기반 폴백. 서버(AI)와 같은 형식의 결과를 낸다.
///
/// 키워드 방식의 한계: 처음 보는 메모에서는 정확도가 60~70% 안팎이다(2026-10-01 측정).
/// 그래서 AI가 기본이고 이 코드는 서버를 못 쓸 때(오프라인·VPN·한도 초과·사용자가 끔)의 대비책이다.
/// 키워드는 가능하면 흔한 단어를 추가하되, 특정 예시에만 맞추지 않는다.
///
/// 글자가 겹치는 단어가 많아 정규식으로 구분한다.
///  - "약": 약속, 예약과 구분 → `(?<!예)약(?!속)`
///  - "운동": 운동화(신발)와 구분 → `운동(?!화)`
///  - "재활": 재활용과 구분 → `재활(?!용)`
///  - "사": 사회·사람과 겹치므로 `사오|사야|사기` 같은 어형으로만 인식
// dart format off
const _keywords = <String, List<String>>{
  '학교': [
    '숙제', '과제', '시험', '수행평가', '수행', '학교', '학원', '공부', '문제집', '교과서',
    '동아리', '발표', '레포트', '보고서', '퀴즈', '중간고사', '기말고사', '모의고사', '단어',
    '암기', '복습', '예습', '과외', '준비물', '선생님', '수업', '오답', '독서', '필기', '교실',
    '평가', '체육복', '실험', '조별', '방과후', '자습', '학습',
  ],
  '건강': [
    '병원', r'(?<!예)약(?!속)', '약국', '치과', r'운동(?!화)', '감기', '진료', '검진', '처방',
    '두통', '헬스', '다이어트', '비타민', r'물.{0,6}마시', '스트레칭', r'재활(?!용)', '열나', '아프',
    '영양제', '건강', '산책', '요가', '조깅',
  ],
  '돈': [
    '요금', '납부', '입금', '송금', '이체', '결제', '용돈', '월세', '회비', '갚', '은행',
    '환불', '청구', '세금', '알바비', '급여', '카드', '대금', r'\d+원',
    r'돈(?!까스|가스)', '급식비', '학원비', '교통비', '등록금', '학비', '수업료', '공과금', '관리비',
    '통신비', '적금', '저금',
  ],
  '쇼핑': [
    '사오', '사야', '사기', '사러', '구매', '구입', '주문', '장보', '마트', '쇼핑', '선물',
    '편의점', '배달', '쿠폰', '택배', '우유', '계란', '식빵', '과일', '세일', '할인',
  ],
  '약속': [
    '약속', '만나', '모임', '미팅', '회의', '파티', '생일', '생신', '친구', '데이트', '영화',
    '외식', '면접', '상담', '예약', '번개', '동창', '식사',
    '할머니', '할아버지', '가족', '친척', '이모', '삼촌', '고모', '외갓집',
  ],
  '할일': [
    '청소', '정리', '빨래', '설거지', '쓰레기', '심부름', '전화', '연락', '신청', '제출',
    '확인', '챙기', '수리', '반납', '택배찾', '충전', '계획', '세우', '분리수거', '재활용',
    '정돈', '빌려', '돌려주', '내놓',
  ],
};
// dart format on

/// 동점이면 이 순서로 정한다(앞쪽이 우선).
const _tieOrder = ['학교', '건강', '돈', '쇼핑', '약속', '할일'];

final _compiled = {
  for (final e in _keywords.entries)
    e.key: [for (final k in e.value) RegExp(k)],
};

const _urgent = [
  '긴급',
  '급하',
  '급히',
  '중요',
  '꼭',
  '반드시',
  '마감',
  '당장',
  '지금',
  '잊지',
  '절대',
];
const _relaxed = ['나중에', '언젠가', '여유', '천천히', '시간날때', '심심', '구경', '생각해'];

/// [memo]를 키워드로 분류한다. [now]는 예약 시각 계산과 우선순위(임박) 판단에 쓴다.
MemoAnalysis classifyByRules(String memo, DateTime now) {
  final text = memo.replaceAll(RegExp(r'\s+'), '');

  var bestCategory = '기타';
  var bestScore = 0;
  for (final category in _tieOrder) {
    final score = _compiled[category]!.where((re) => re.hasMatch(text)).length;
    if (score > bestScore) {
      bestScore = score;
      bestCategory = category;
    }
  }

  final due = parseDue(memo, now);
  return MemoAnalysis(
    category: bestCategory,
    priority: _priority(text, due, now),
    summary: _summary(memo),
    due: due,
    source: AnalysisSource.rules,
  );
}

MemoPriority _priority(String text, ParsedDue? due, DateTime now) {
  if (_urgent.any(text.contains)) return MemoPriority.high;
  // 24시간 안에 있는 일정은 급한 일로 본다.
  if (due != null && due.at.difference(now) <= const Duration(hours: 24)) {
    return MemoPriority.high;
  }
  if (_relaxed.any(text.contains)) return MemoPriority.low;
  return MemoPriority.normal;
}

/// 짧은 메모는 요약 없이 비우고, 긴 메모는 첫 문장을 30자 안으로 줄인다.
String _summary(String memo) {
  final trimmed = memo.trim();
  if (trimmed.length <= summaryMinMemoLength) return '';
  final firstSentence = trimmed.split(RegExp(r'[\n.!?。]')).first.trim();
  final base = firstSentence.isEmpty ? trimmed : firstSentence;
  if (base.length <= maxSummaryLength) return base;
  return '${base.substring(0, maxSummaryLength - 1).trimRight()}…';
}

/// 분류가 없는 메모에 기본(규칙 기반) 분석으로 카테고리·우선순위를 채운다.
/// 이미 분류가 있으면(✨로 적용했거나 이전에 채웠으면) 그대로 돌려준다. 요약은 건드리지 않는다.
/// [now]는 우선순위(일정이 임박한지) 판단의 기준 시각이다.
MemoEntry withRuleClassification(MemoEntry entry, DateTime now) {
  if (entry.category != null) return entry;
  final a = classifyByRules(entry.memo, now);
  return entry.copyWith(category: a.category, priority: a.priority);
}

/// 저장된 내역 중 분류가 없는 것을 기본 분석으로 채운다(앱을 열 때 한 번).
/// 우선순위는 메모를 쓴 시각 기준으로 판단하고, 쓴 시각을 모르면(0) [now]를 쓴다.
({List<MemoEntry> list, bool changed}) backfillClassification(
  List<MemoEntry> list,
  DateTime now,
) {
  var changed = false;
  final out = [
    for (final e in list)
      if (e.category != null)
        e
      else
        () {
          changed = true;
          final reference = e.time == 0
              ? now
              : DateTime.fromMillisecondsSinceEpoch(e.time);
          return withRuleClassification(e, reference);
        }(),
  ];
  return (list: out, changed: changed);
}
