const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// "10월 2일 (금)". [today]와 연도가 다르면 "2027년 1월 3일 (일)".
String dateLabel(DateTime d, {required DateTime today}) {
  final year = d.year == today.year ? '' : '${d.year}년 ';
  return '$year${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
}
