import '../models/memo_analysis.dart';
import '../models/memo_entry.dart';

// 우선순위 값을 화면에 보여줄 한글로 바꾼다
String priorityLabel(MemoPriority p) => switch (p) {
  MemoPriority.low => '낮음',
  MemoPriority.normal => '보통',
  MemoPriority.high => '높음',
};

/// 자동 정리를 적용한 메모의 "학교 · 우선순위 보통" 표시. 정리하지 않은 메모는 null.
String? classLabel(MemoEntry e) => e.category == null
    ? null
    : '${e.category} · 우선순위 ${priorityLabel(e.priority)}';

/// AI 대신 기본(규칙 기반) 분석을 쓰게 된 이유를 사용자에게 알리는 문구.
String fallbackMessage(FallbackReason reason) => switch (reason) {
  FallbackReason.disabled => 'AI를 쓰지 않도록 설정돼 있어 기본 분석으로 정리했어요.',
  FallbackReason.dailyLimit => '오늘 AI 사용 횟수를 모두 써서 기본 분석으로 정리했어요.',
  FallbackReason.offline => '인터넷에 연결되지 않아 기본 분석으로 정리했어요.',
  FallbackReason.timeout => 'AI 응답이 늦어 기본 분석으로 정리했어요.',
  FallbackReason.quotaExceeded => '오늘 AI 사용량이 모두 소진돼 기본 분석으로 정리했어요.',
  FallbackReason.rateLimited => '요청이 많아 지금은 기본 분석으로 정리했어요. 잠시 뒤에 다시 해보세요.',
  FallbackReason.serverError => 'AI 서버에 문제가 있어 기본 분석으로 정리했어요.',
};

// 요일 이름(월요일이 0번)
const _weekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// "10월 2일 (금) 오후 3시", 분이 있으면 "오후 3시 30분".
String formatDueLabel(DateTime t) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour < 12 ? '오전' : '오후';
  final minute = t.minute == 0 ? '' : ' ${t.minute}분';
  return '${t.month}월 ${t.day}일 (${_weekdayNames[t.weekday - 1]}) $ampm $hour12시$minute';
}
