// 메모 시각을 목록에 보여줄 문자열로 바꾼다. 오늘이면 시간만, 올해면 월/일, 아니면 연도까지 붙인다.
String formatEntryTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final h = dt.hour;
  final ampm = h < 12 ? '오전' : '오후';
  // 0시는 12시, 13시 이후는 12를 빼서 12시간제로 맞춘다
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final m = dt.minute.toString().padLeft(2, '0');
  final timeStr = '$ampm $h12:$m';
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return timeStr;
  }
  if (dt.year == now.year) {
    return '${dt.month}/${dt.day} $timeStr';
  }
  return '${dt.year}/${dt.month}/${dt.day} $timeStr';
}
