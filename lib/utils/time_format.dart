String formatEntryTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final h = dt.hour;
  final ampm = h < 12 ? '오전' : '오후';
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
