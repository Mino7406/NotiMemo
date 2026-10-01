/// 메모에서 "언제"를 찾아 예약 시각을 계산하는 규칙 기반 한국어 시간 파서.
///
/// LLM은 요일 표현을 체계적으로 한 주 뒤로 계산해서(2026-10-01 실험) 시각 계산은 이 코드가
/// 맡는다. 오프라인에서도 같은 결과가 나오고 단위 테스트로 정확도를 보장한다.
/// 확실하지 않으면 null을 돌려주는 쪽을 택한다(잘못된 알림 시각이 더 해롭다).
class ParsedDue {
  final DateTime at;

  /// 메모에 시각이 명시됐는지. false면 날짜만 있어서 [defaultHour]시로 채운 값이다.
  final bool hasTime;

  const ParsedDue(this.at, {required this.hasTime});

  @override
  String toString() => 'ParsedDue($at, hasTime: $hasTime)';
}

/// 날짜만 있고 시각이 없을 때 쓰는 시각(오전 9시).
const defaultHour = 9;

const _weekdayIndex = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};

/// 날짜가 이미 지났을 때 어떻게 할지.
enum _Roll { none, plusWeek, nextYear, nextMonth }

class _Day {
  final DateTime date; // 시각 없는 날짜
  final _Roll roll;
  const _Day(this.date, this.roll);
}

class _Time {
  final List<int> hours; // 후보 시(0~23). 여러 개면 애매한 경우(오전/오후)
  final int minute;
  final int dayOffset; // 밤 12시/자정은 다음 날 0시
  final bool explicit; // 시각을 직접 말했는지(false면 "저녁" 같은 시간대 단어만)
  const _Time(
    this.hours,
    this.minute, {
    this.dayOffset = 0,
    this.explicit = true,
  });
}

/// "2027년 3월 5일", "10월 15일"
final _absoluteDate = RegExp(r'(?:(\d{4})년)?(\d{1,2})월(\d{1,2})일');

int _absYear(RegExpMatch m, DateTime today) =>
    m.group(1) != null ? int.parse(m.group(1)!) : today.year;

DateTime _day(DateTime d, int plusDays) =>
    DateTime(d.year, d.month, d.day + plusDays);

bool _validDate(int y, int m, int d) {
  final t = DateTime(y, m, d);
  return t.year == y && t.month == m && t.day == d;
}

/// [memo]에서 예약 시각을 찾는다. 없으면 null. [now]보다 과거인 결과는 돌려주지 않는다.
ParsedDue? parseDue(String memo, DateTime now) {
  final t = memo.replaceAll(RegExp(r'\s+'), '');
  final nowMin = DateTime(now.year, now.month, now.day, now.hour, now.minute);
  final today = _day(nowMin, 0);

  // 반복 일정("매주 월요일")은 한 번짜리 예약으로 바꾸면 오해를 주므로 제안하지 않는다.
  if (RegExp(r'매(?:일|주|달|월|년)').hasMatch(t)) return null;

  // 1) "30분 뒤", "2시간 후", "1시간 30분 뒤": 지금 기준 상대 시간
  for (final m in RegExp(
    r'(?:(\d{1,3})시간)?(?:(\d{1,3})분)?(?:뒤|후)',
  ).allMatches(t)) {
    final hours = int.tryParse(m.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(m.group(2) ?? '') ?? 0;
    if (hours == 0 && minutes == 0) continue;
    return ParsedDue(
      nowMin.add(Duration(hours: hours, minutes: minutes)),
      hasTime: true,
    );
  }

  // 월·일을 직접 적었는데 존재하지 않는 날짜(2월 30일 등)면, 시각만 따로 읽어 엉뚱한 날에
  // 예약하지 않도록 통째로 포기한다.
  final abs = _absoluteDate.firstMatch(t);
  if (abs != null &&
      !_validDate(
        _absYear(abs, today),
        int.parse(abs.group(2)!),
        int.parse(abs.group(3)!),
      )) {
    return null;
  }

  final day = _findDay(t, today, nowMin);
  final time = _findTime(t, hasDay: day != null);

  if (day == null) {
    if (time == null || !time.explicit) return null;
    return _timeOnly(time, today, nowMin);
  }

  // 날짜가 있는 경우
  if (time == null) {
    return _finish(
      DateTime(day.date.year, day.date.month, day.date.day, defaultHour),
      day,
      nowMin,
      hasTime: false,
    );
  }
  final base = _day(day.date, time.dayOffset);
  final isToday = day.date == today;
  DateTime? picked;
  final cands = [
    for (final h in time.hours)
      DateTime(base.year, base.month, base.day, h, time.minute),
  ];
  if (isToday) {
    // 오늘이면 아직 오지 않은 가장 이른 후보. 모두 지났으면 마지막 후보(과거 처리로 이어짐)
    picked = cands.firstWhere(
      (c) => c.isAfter(nowMin),
      orElse: () => cands.last,
    );
  } else {
    picked = cands.first; // 다른 날은 애매할 때 오전(7~11시)으로 본다
  }
  return _finish(picked, day, nowMin, hasTime: true);
}

/// 날짜 없이 시각만 있을 때: 오늘 중 가장 가까운 미래, 없으면 내일.
ParsedDue? _timeOnly(_Time time, DateTime today, DateTime nowMin) {
  for (final offset in [time.dayOffset, time.dayOffset + 1]) {
    final base = _day(today, offset);
    for (final h in time.hours) {
      final c = DateTime(base.year, base.month, base.day, h, time.minute);
      if (c.isAfter(nowMin)) return ParsedDue(c, hasTime: true);
    }
  }
  return null;
}

ParsedDue? _finish(
  DateTime at,
  _Day day,
  DateTime nowMin, {
  required bool hasTime,
}) {
  var result = at;
  if (!result.isAfter(nowMin)) {
    switch (day.roll) {
      case _Roll.none:
        return null;
      case _Roll.plusWeek:
        result = DateTime(at.year, at.month, at.day + 7, at.hour, at.minute);
      case _Roll.nextYear:
        if (!_validDate(at.year + 1, at.month, at.day)) return null;
        result = DateTime(at.year + 1, at.month, at.day, at.hour, at.minute);
      case _Roll.nextMonth:
        final y = at.month == 12 ? at.year + 1 : at.year;
        final m = at.month == 12 ? 1 : at.month + 1;
        if (!_validDate(y, m, at.day)) return null;
        result = DateTime(y, m, at.day, at.hour, at.minute);
    }
    if (!result.isAfter(nowMin)) return null;
  }
  return ParsedDue(result, hasTime: hasTime);
}

_Day? _findDay(String t, DateTime today, DateTime nowMin) {
  // 연·월·일 직접 지정: "2027년 3월 5일", "10월 15일"
  final abs = RegExp(r'(?:(\d{4})년)?(\d{1,2})월(\d{1,2})일').firstMatch(t);
  if (abs != null) {
    final explicitYear = abs.group(1) != null;
    final y = explicitYear ? int.parse(abs.group(1)!) : today.year;
    final m = int.parse(abs.group(2)!);
    final d = int.parse(abs.group(3)!);
    if (!_validDate(y, m, d)) return null;
    return _Day(DateTime(y, m, d), explicitYear ? _Roll.none : _Roll.nextYear);
  }
  // "10/15" (분수·수량 표현은 제외)
  final slash = RegExp(
    r'(?<![0-9/])(\d{1,2})/(\d{1,2})(?![0-9]|컵|개|쪽|배|장|명|인분)',
  ).firstMatch(t);
  if (slash != null) {
    final m = int.parse(slash.group(1)!);
    final d = int.parse(slash.group(2)!);
    if (_validDate(today.year, m, d)) {
      return _Day(DateTime(today.year, m, d), _Roll.nextYear);
    }
  }

  // 오늘·내일·모레·글피 (내일모레는 모레)
  if (t.contains('모레')) return _Day(_day(today, 2), _Roll.none);
  if (t.contains('글피')) return _Day(_day(today, 3), _Roll.none);
  if (t.contains('내일') || RegExp(r'낼(?!름)').hasMatch(t)) {
    return _Day(_day(today, 1), _Roll.none);
  }
  if (t.contains('오늘')) return _Day(today, _Roll.none);

  // "3일 뒤", "일주일 뒤", "2주 후"
  final days = RegExp(r'(\d{1,3})일(?:뒤|후)').firstMatch(t);
  if (days != null) {
    return _Day(_day(today, int.parse(days.group(1)!)), _Roll.none);
  }
  if (RegExp(r'일주일(?:뒤|후)').hasMatch(t)) {
    return _Day(_day(today, 7), _Roll.none);
  }
  final weeks = RegExp(r'(\d{1,2})주(?:일)?(?:뒤|후)').firstMatch(t);
  if (weeks != null) {
    return _Day(_day(today, 7 * int.parse(weeks.group(1)!)), _Roll.none);
  }

  // 요일: "금요일", "다음주 월요일", "담주 수욜", "이번주말"
  final wd = RegExp(
    r'(?:(다다음|이번|다음|담)주)?(월|화|수|목|금|토|일)(?:요일|욜)',
  ).firstMatch(t);
  final String? weekPrefix;
  final int? index;
  if (wd != null) {
    weekPrefix = wd.group(1);
    index = _weekdayIndex[wd.group(2)!];
  } else if (t.contains('주말')) {
    weekPrefix = RegExp(r'(이번|다음|담)주말').firstMatch(t)?.group(1);
    index = 6;
  } else {
    weekPrefix = null;
    index = null;
  }
  if (index != null) {
    final monday = _day(today, -(today.weekday - 1));
    switch (weekPrefix) {
      case '이번':
        return _Day(_day(monday, index - 1), _Roll.none);
      case '다음':
      case '담':
        return _Day(_day(monday, 7 + index - 1), _Roll.none);
      case '다다음':
        return _Day(_day(monday, 14 + index - 1), _Roll.none);
      default:
        final diff = (index - today.weekday) % 7;
        return _Day(_day(today, diff), _Roll.plusWeek);
    }
  }

  // "15일" (몇 월인지 없음): 이번 달, 지났으면 다음 달
  final dom = RegExp(r'(\d{1,2})일(?!간|째|뒤|후|전|동안|요일)').firstMatch(t);
  if (dom != null) {
    final d = int.parse(dom.group(1)!);
    if (_validDate(today.year, today.month, d)) {
      return _Day(DateTime(today.year, today.month, d), _Roll.nextMonth);
    }
  }
  return null;
}

_Time? _findTime(String t, {required bool hasDay}) {
  // "15:30"
  final colon = RegExp(r'(?<![0-9])(\d{1,2}):(\d{2})').firstMatch(t);
  if (colon != null) {
    final h = int.parse(colon.group(1)!);
    final m = int.parse(colon.group(2)!);
    if (h <= 23 && m <= 59) return _Time([h], m);
  }

  // "오후 3시 30분", "저녁 7시", "3시 반" ("3시간"은 시간 길이라 제외)
  for (final match in RegExp(
    r'(오전|오후|아침|점심|저녁|밤|새벽)?(\d{1,2})시(?!간)(?:(\d{1,2})분|(반))?',
  ).allMatches(t)) {
    final part = match.group(1);
    final h = int.parse(match.group(2)!);
    final minute = match.group(4) != null
        ? 30
        : int.tryParse(match.group(3) ?? '') ?? 0;
    if (h > 24 || minute > 59) continue;
    return _resolveHour(part, h, minute);
  }

  // "정오", "자정"
  if (t.contains('정오')) return const _Time([12], 0);
  if (t.contains('자정')) return const _Time([0], 0, dayOffset: 1);

  // 시간대 단어만 있을 때는 날짜가 함께 있을 때만 인정한다("내일 저녁").
  if (hasDay) {
    if (t.contains('아침')) return const _Time([8], 0, explicit: false);
    if (t.contains('점심')) return const _Time([12], 0, explicit: false);
    if (t.contains('저녁')) return const _Time([18], 0, explicit: false);
    if (t.contains('새벽')) return const _Time([5], 0, explicit: false);
    if (t.contains('밤')) return const _Time([21], 0, explicit: false);
  }
  return null;
}

_Time _resolveHour(String? part, int h, int minute) {
  switch (part) {
    case '오전':
    case '아침':
    case '새벽':
      return _Time([h % 12], minute); // 오전 12시 = 0시
    case '오후':
    case '점심':
      return _Time([h == 12 ? 12 : (h < 12 ? h + 12 : h)], minute);
    case '저녁':
    case '밤':
      // 밤 12시 = 다음 날 0시
      if (h == 12 || h == 24) {
        return _Time([0], minute, dayOffset: 1);
      }
      return _Time([h < 12 ? h + 12 : h], minute);
  }
  // 오전/오후 표시가 없는 경우
  if (h == 24) return _Time([0], minute, dayOffset: 1);
  if (h >= 13 || h == 0 || h == 12) return _Time([h], minute);
  if (h <= 6) return _Time([h + 12], minute); // 1~6시는 오후로 본다
  return _Time([h, h + 12], minute); // 7~11시는 애매함: 오전 우선, 오늘이면 아직 안 지난 쪽
}
