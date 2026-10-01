import '../utils/due_parser.dart';
import 'memo_entry.dart';

/// 서버(worker/src/classify.js)의 CATEGORIES와 같은 목록이다. 한쪽을 바꾸면 다른 쪽도 맞춘다.
const memoCategories = ['학교', '할일', '약속', '쇼핑', '건강', '돈', '기타'];

/// 분석 결과가 어디서 나왔는지. 화면에서 "AI 분석"/"오프라인 분석"을 구분해 보여준다.
enum AnalysisSource { ai, rules }

/// 메모 한 건의 분석 결과.
class MemoAnalysis {
  final String category;
  final MemoPriority priority;

  /// 한 줄 요약. 짧은 메모는 빈 문자열(원문을 그대로 보여준다).
  final String summary;

  /// 메모에서 찾은 예약 시각(없으면 null). AI든 규칙이든 같은 시간 파서가 계산한다.
  final ParsedDue? due;

  final AnalysisSource source;

  const MemoAnalysis({
    required this.category,
    required this.priority,
    required this.summary,
    required this.due,
    required this.source,
  });
}

/// 서버가 보낸 우선순위 문자열을 [MemoPriority]로. 모르는 값은 normal.
MemoPriority priorityFromName(String? name) =>
    MemoPriority.values.asNameMap()[name] ?? MemoPriority.normal;

/// 이 길이 이하의 짧은 메모는 요약을 만들지 않는다(서버와 같은 기준).
const summaryMinMemoLength = 25;
const maxSummaryLength = 30;
