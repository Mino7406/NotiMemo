import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/utils/date_label.dart';

void main() {
  final today = DateTime(2026, 10, 1);

  test('오늘·내일도 날짜로 표기', () {
    expect(dateLabel(today, today: today), '10월 1일 (목)');
    expect(dateLabel(DateTime(2026, 10, 2), today: today), '10월 2일 (금)');
  });

  test('다른 해는 연도를 붙인다', () {
    expect(dateLabel(DateTime(2027, 1, 3), today: today), '2027년 1월 3일 (일)');
  });
}
