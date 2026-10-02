import '../models/memo_analysis.dart';
import '../models/memo_entry.dart';

/// 알림 내역·예약 목록에서 분류(카테고리)와 우선순위로 걸러 보는 조건.
/// 둘 다 고르면 둘을 모두 만족하는 것만 보인다. null은 "전체".
class ClassFilter {
  final String? category;
  final MemoPriority? priority;

  const ClassFilter({this.category, this.priority});

  static const none = ClassFilter();

  bool get isActive => category != null || priority != null;

  /// [category]는 분류가 없는(자동 분류를 껐던) 메모면 null. 분류를 고른 필터에는 걸리지 않는다.
  bool matches(String? category, MemoPriority priority) =>
      (this.category == null || this.category == category) &&
      (this.priority == null || this.priority == priority);

  ClassFilter withCategory(String? value) =>
      ClassFilter(category: value, priority: priority);

  ClassFilter withPriority(MemoPriority? value) =>
      ClassFilter(category: category, priority: value);

  /// 목록이 바뀌어 [category]/[priority]에 해당하는 항목이 더는 없으면 그 조건을 푼다
  /// (지운 뒤에 아무것도 안 보이는 화면에 갇히지 않도록).
  ClassFilter normalizedFor(
    Iterable<({String? category, MemoPriority priority})> items,
  ) {
    final cats = categoriesIn(items.map((e) => e.category));
    final pris = items.map((e) => e.priority).toSet();
    return ClassFilter(
      category: category != null && cats.contains(category) ? category : null,
      priority: priority != null && pris.contains(priority) ? priority : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClassFilter &&
      other.category == category &&
      other.priority == priority;

  @override
  int get hashCode => Object.hash(category, priority);
}

/// [categories] 중 실제로 있는 카테고리를 [memoCategories] 순서대로(중복 없이).
List<String> categoriesIn(Iterable<String?> categories) {
  final present = categories.whereType<String>().toSet();
  return [
    for (final c in memoCategories)
      if (present.contains(c)) c,
  ];
}

/// 필터를 통과하는 항목의 **원래 위치(인덱스)** 목록. 화면에는 걸러진 항목만 보이지만
/// 삭제·재생성은 원래 목록의 위치로 처리하므로 위치를 함께 돌려준다.
List<int> visibleIndexes<T>(
  List<T> items,
  ClassFilter filter,
  ({String? category, MemoPriority priority}) Function(T) classOf,
) {
  return [
    for (var i = 0; i < items.length; i++)
      if (filter.matches(
        classOf(items[i]).category,
        classOf(items[i]).priority,
      ))
        i,
  ];
}
