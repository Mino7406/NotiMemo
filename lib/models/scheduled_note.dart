import 'dart:convert';

/// 예약 고정 한 건. 네이티브 `AlarmScheduler`가 `scheduled_notes`에 기록한다.
class ScheduledNote {
  final String id;
  final String memo;

  /// 고정될 시각 (ms since epoch)
  final int at;

  const ScheduledNote({required this.id, required this.memo, required this.at});

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(at);

  /// 깨진 값은 빈 목록, 결과는 시각이 빠른 순.
  static List<ScheduledNote> parseList(String? raw) {
    if (raw == null) return [];
    try {
      final list = [
        for (final o in jsonDecode(raw) as List)
          ScheduledNote(
            id: (o as Map)['id'] as String,
            memo: o['memo'] as String,
            at: (o['at'] as num).toInt(),
          ),
      ];
      list.sort((a, b) => a.at.compareTo(b.at));
      return list;
    } catch (_) {
      return [];
    }
  }
}
