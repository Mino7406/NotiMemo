import 'due_parser.dart';

/// 일정 시각에 딱 맞춘 알림은 이미 늦은 때라서, 시각이 명시된 일정은 여유를 두고 알린다.
/// 알림 시각 제안: 일정 시각과 그보다 앞선 알림 시각.
class ReminderSuggestion {
  final DateTime eventAt;
  final DateTime remindAt;

  const ReminderSuggestion(this.eventAt, this.remindAt);

  /// 일정 시각보다 얼마나 앞서 알리는지. 0이면 여유 없음.
  Duration get lead => eventAt.difference(remindAt);
}

/// 기본 여유 시간(분).
const defaultLeadMinutes = 30;

/// 일정 시각의 [leadMinutes]분 전을 알림 시각으로 제안한다. 이미 그 시각이 지났으면 5분 뒤
/// (일정이 5분 안쪽이면 일정 시각)로 당긴다. 날짜만 있고 시각이 없는 일정은 그대로 둔다.
ReminderSuggestion suggestReminder(
  ParsedDue due,
  DateTime now, {
  int leadMinutes = defaultLeadMinutes,
}) {
  if (!due.hasTime || leadMinutes <= 0) {
    return ReminderSuggestion(due.at, due.at);
  }
  // 일정 시각에서 여유 시간만큼 앞으로 당긴다
  var remind = due.at.subtract(Duration(minutes: leadMinutes));
  if (!remind.isAfter(now)) {
    // 당긴 시각이 이미 지났으면 지금부터 5분 뒤로 잡는다
    final soon = now.add(const Duration(minutes: 5));
    remind = soon.isAfter(due.at) ? due.at : soon;
  }
  return ReminderSuggestion(due.at, remind);
}

/// "30분 전", "1시간 전", "1시간 30분 전". 0이면 null.
String? leadLabel(Duration lead) {
  final m = lead.inMinutes;
  if (m <= 0) return null;
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '$r분 전';
  return r == 0 ? '$h시간 전' : '$h시간 $r분 전';
}
