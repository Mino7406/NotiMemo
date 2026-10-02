import '../utils/due_parser.dart';
import 'memo_entry.dart';

/// 서버(worker/src/classify.js)의 CATEGORIES와 같은 목록이다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
const memoCategories = ['학교', '할일', '약속', '쇼핑', '건강', '돈', '기타'];

/// 분석 결과가 어디서 나왔는지. 화면에서 "AI 분석"/"기본 분석"을 구분해 보여준다.
enum AnalysisSource { ai, rules }

/// AI 대신 규칙 기반 분석을 쓰게 된 이유. 화면에서 이유에 맞는 안내를 보여준다.
enum FallbackReason {
  /// 사용자가 AI 분류에 동의하지 않았거나 설정에서 껐다.
  disabled,

  /// 이 기기의 하루 호출 상한을 다 썼다.
  dailyLimit,

  /// 인터넷에 연결할 수 없다(오프라인, VPN·네트워크 차단 포함).
  offline,

  /// 서버 응답이 너무 늦다.
  timeout,

  /// 서버의 하루 무료 사용량이 소진됐다.
  quotaExceeded,

  /// 짧은 시간에 너무 많이 요청했다.
  rateLimited,

  /// 서버 오류나 이해할 수 없는 응답.
  serverError,
}

/// 메모 한 건의 분석 결과.
class MemoAnalysis {
  final String category;
  final MemoPriority priority;

  /// 한 줄 요약. 짧은 메모는 빈 문자열(원문을 그대로 보여준다).
  final String summary;

  /// 메모에서 찾은 예약 시각(없으면 null). AI든 규칙이든 같은 시간 파서가 계산한다.
  final ParsedDue? due;

  final AnalysisSource source;

  /// [source]가 rules일 때, AI 대신 규칙을 쓰게 된 이유. ai면 null.
  final FallbackReason? fallbackReason;

  const MemoAnalysis({
    required this.category,
    required this.priority,
    required this.summary,
    required this.due,
    required this.source,
    this.fallbackReason,
  });

  // 기존 결과에 "왜 기본 분석을 썼는지"만 덧붙인 복사본을 만든다
  MemoAnalysis withFallbackReason(FallbackReason reason) => MemoAnalysis(
    category: category,
    priority: priority,
    summary: summary,
    due: due,
    source: source,
    fallbackReason: reason,
  );
}

/// 서버가 보낸 우선순위 문자열을 [MemoPriority]로. 모르는 값은 normal.
MemoPriority priorityFromName(String? name) =>
    MemoPriority.values.asNameMap()[name] ?? MemoPriority.normal;

/// 이 길이 이하의 짧은 메모는 요약을 만들지 않는다(서버와 같은 기준).
const summaryMinMemoLength = 25;
// 요약 최대 글자 수
const maxSummaryLength = 30;
