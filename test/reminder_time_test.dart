import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/utils/due_parser.dart';
import 'package:notimemo/utils/reminder_time.dart';

void main() {
  final now = DateTime(2026, 10, 1, 12, 0);
  ParsedDue due(DateTime at, {bool hasTime = true}) =>
      ParsedDue(at, hasTime: hasTime);

  test('기본은 30분 전', () {
    final s = suggestReminder(due(DateTime(2026, 10, 2, 15, 0)), now);
    expect(s.remindAt, DateTime(2026, 10, 2, 14, 30));
    expect(s.lead, const Duration(minutes: 30));
  });

  test('설정한 여유 시간만큼 앞당긴다', () {
    final at = DateTime(2026, 10, 2, 15, 0);
    expect(
      suggestReminder(due(at), now, leadMinutes: 10).remindAt,
      DateTime(2026, 10, 2, 14, 50),
    );
    expect(
      suggestReminder(due(at), now, leadMinutes: 120).remindAt,
      DateTime(2026, 10, 2, 13, 0),
    );
  });

  test('0분이면 일정 시각 그대로', () {
    final at = DateTime(2026, 10, 2, 15, 0);
    final s = suggestReminder(due(at), now, leadMinutes: 0);
    expect(s.remindAt, at);
    expect(leadLabel(s.lead), isNull);
  });

  test('여유를 빼면 지난 시각이면 지금부터 5분 뒤', () {
    final s = suggestReminder(due(DateTime(2026, 10, 1, 12, 20)), now);
    expect(s.remindAt, DateTime(2026, 10, 1, 12, 5));
    expect(s.lead, const Duration(minutes: 15));
  });

  test('일정이 5분 안쪽이면 일정 시각', () {
    final s = suggestReminder(due(DateTime(2026, 10, 1, 12, 3)), now);
    expect(s.remindAt, DateTime(2026, 10, 1, 12, 3));
  });

  test('시각이 없는 일정은 그대로', () {
    final s = suggestReminder(
      due(DateTime(2026, 10, 2, 9, 0), hasTime: false),
      now,
    );
    expect(s.remindAt, s.eventAt);
  });

  test('여유 문구', () {
    expect(leadLabel(const Duration(minutes: 10)), '10분 전');
    expect(leadLabel(const Duration(minutes: 60)), '1시간 전');
    expect(leadLabel(const Duration(minutes: 90)), '1시간 30분 전');
  });
}
