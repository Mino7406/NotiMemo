import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_analysis.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/utils/analysis_labels.dart';

void main() {
  test('우선순위 문구', () {
    expect(priorityLabel(MemoPriority.low), '낮음');
    expect(priorityLabel(MemoPriority.normal), '보통');
    expect(priorityLabel(MemoPriority.high), '높음');
  });

  test('모든 폴백 이유에 서로 다른 안내 문구가 있다', () {
    final messages = {for (final r in FallbackReason.values) r: fallbackMessage(r)};
    expect(messages.values.every((m) => m.isNotEmpty), isTrue);
    expect(messages.values.toSet().length, FallbackReason.values.length);
    for (final m in messages.values) {
      expect(m, contains('기본 분석'));
    }
  });

  test('예약 시각 표시', () {
    expect(formatDueLabel(DateTime(2026, 10, 2, 15)), '10월 2일 (금) 오후 3시');
    expect(formatDueLabel(DateTime(2026, 10, 2, 15, 30)), '10월 2일 (금) 오후 3시 30분');
    expect(formatDueLabel(DateTime(2026, 10, 5, 9)), '10월 5일 (월) 오전 9시');
    expect(formatDueLabel(DateTime(2026, 10, 3, 0, 5)), '10월 3일 (토) 오전 12시 5분');
    expect(formatDueLabel(DateTime(2026, 10, 4, 12)), '10월 4일 (일) 오후 12시');
  });
}
