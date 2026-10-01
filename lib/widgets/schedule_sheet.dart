import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/date_label.dart';

/// 예약 시각을 고르는 하단 시트. 확인하면 고른 시각을, 닫으면 null을 돌려준다.
/// [initial]을 주면 그 시각으로 미리 맞춰 둔다(미래이고 선택 범위 안일 때만, 아니면 기본값).
/// 날짜는 휠로, 시각은 오전/오후 토글과 시·분 입력 칸으로 고른다(칸은 직접 입력하거나 ▲▼로 바꾼다).
Future<DateTime?> showScheduleSheet(BuildContext context, {DateTime? initial}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ScheduleSheet(initial: initial),
  );
}

/// 숫자 입력이 [max]를 넘으면 그 글자를 받지 않는다(시는 12, 분은 59까지만 쳐진다).
class _MaxValueFormatter extends TextInputFormatter {
  final int max;
  const _MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final v = int.tryParse(newValue.text);
    return v != null && v > max ? oldValue : newValue;
  }
}

/// 날짜 휠이 보여 주는 일수(약 1년).
const _dayCount = 365;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class _ScheduleSheet extends StatefulWidget {
  final DateTime? initial;
  const _ScheduleSheet({this.initial});

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  static const _itemExtent = 44.0;

  late final DateTime _today = _dateOnly(DateTime.now());

  /// 마지막으로 올바르게 정해진 시각. 입력 칸이 잘못된 동안에는 이 값이 그대로 남는다.
  late DateTime _selected = _initialSelection();

  late final _dayCtrl = FixedExtentScrollController(initialItem: _dayIndex);
  late final _hourCtrl = TextEditingController(text: '$_hour12');
  late final _minCtrl = TextEditingController(text: _two(_selected.minute));

  DateTime _initialSelection() {
    final now = DateTime.now();
    final wanted = widget.initial;
    if (wanted != null && wanted.isAfter(now)) {
      final days = _dateOnly(wanted).difference(_dateOnly(now)).inDays;
      if (days < _dayCount) {
        return DateTime(
          wanted.year,
          wanted.month,
          wanted.day,
          wanted.hour,
          wanted.minute,
        );
      }
    }
    final t = now.add(const Duration(minutes: 10));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  int get _dayIndex => _dateOnly(_selected).difference(_today).inDays;
  bool get _pm => _selected.hour >= 12;
  int get _hour12 => _selected.hour % 12 == 0 ? 12 : _selected.hour % 12;

  /// 시 칸은 1~12(오전/오후 토글과 함께 쓰므로 24시간제로 헷갈리지 않게), 분 칸은 0~59.
  String? get _problem {
    final h = int.tryParse(_hourCtrl.text);
    if (h == null) return '시를 입력하세요';
    if (h < 1 || h > 12) return '시는 1~12로 입력하세요';
    final m = int.tryParse(_minCtrl.text);
    if (m == null) return '분을 입력하세요';
    if (m > 59) return '분은 0~59로 입력하세요';
    return null;
  }

  bool get _hourBad {
    final h = int.tryParse(_hourCtrl.text);
    return _hourCtrl.text.isNotEmpty && (h == null || h < 1 || h > 12);
  }

  bool get _minBad {
    final m = int.tryParse(_minCtrl.text);
    return _minCtrl.text.isNotEmpty && (m == null || m > 59);
  }

  bool get _canConfirm => _problem == null && _selected.isAfter(DateTime.now());

  String get _confirmLabel {
    final p = _problem;
    if (p != null) return p;
    if (!_selected.isAfter(DateTime.now())) return '지난 시각이에요';
    final day = dateLabel(_selected, today: _today);
    return '$day ${_pm ? '오후' : '오전'} $_hour12:${_two(_selected.minute)}에 고정';
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  /// 입력 칸 내용이 올바르면 [_selected]에 반영한다.
  void _onTyped() {
    if (_problem == null) {
      final h = int.parse(_hourCtrl.text);
      final m = int.parse(_minCtrl.text);
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        h % 12 + (_pm ? 12 : 0),
        m,
      );
    }
    setState(() {});
  }

  void _setPm(bool pm) {
    if (pm == _pm) return;
    setState(() {
      _selected = _selected.add(Duration(hours: pm ? 12 : -12));
    });
  }

  /// ▲▼ 버튼. 시는 1~12, 분은 0~59 안에서 돌아가고, 서로 자리올림하지 않는다.
  void _step({required bool hour, required int delta}) {
    FocusScope.of(context).unfocus();
    setState(() {
      if (hour) {
        final h = ((_hour12 - 1 + delta) % 12 + 12) % 12 + 1;
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day,
          h % 12 + (_pm ? 12 : 0),
          _selected.minute,
        );
      } else {
        final m = ((_selected.minute + delta) % 60 + 60) % 60;
        _selected = DateTime(
          _selected.year,
          _selected.month,
          _selected.day,
          _selected.hour,
          m,
        );
      }
      _syncFields();
    });
  }

  void _syncFields() {
    _hourCtrl.text = '$_hour12';
    _minCtrl.text = _two(_selected.minute);
  }

  void _onDayWheel(int i) {
    final d = _today.add(Duration(days: i.clamp(0, _dayCount - 1)));
    setState(() {
      _selected = DateTime(
        d.year,
        d.month,
        d.day,
        _selected.hour,
        _selected.minute,
      );
    });
  }

  /// 빠른 선택 칩: 값을 정하고 날짜 휠과 입력 칸을 그 값으로 맞춘다.
  void _jumpTo(DateTime t) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = DateTime(t.year, t.month, t.day, t.hour, t.minute);
      _syncFields();
    });
    _dayCtrl.animateToItem(
      _dayIndex.clamp(0, _dayCount - 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  List<(String, DateTime)> _quickPicks() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final picks = <(String, DateTime)>[
      ('5분 뒤', base.add(const Duration(minutes: 5))),
      ('30분 뒤', base.add(const Duration(minutes: 30))),
      ('1시간 뒤', base.add(const Duration(hours: 1))),
    ];
    final evening = DateTime(now.year, now.month, now.day, 19);
    if (evening.isAfter(now)) picks.add(('오늘 저녁 7시', evening));
    final tomorrow = _today.add(const Duration(days: 1));
    picks.add((
      '내일 아침 8시',
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8),
    ));
    return picks;
  }

  String _dayLabel(int i) =>
      dateLabel(_today.add(Duration(days: i)), today: _today);

  Widget _ampmToggle(Color border, Color sub) {
    Widget seg(String label, bool pm) {
      final on = _pm == pm;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _setPm(pm),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.gradStart.withAlpha(30) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.gradStart : sub,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [seg('오전', false), seg('오후', true)]),
    );
  }

  /// 숫자 입력 칸 + 위아래 ▲▼.
  Widget _timeBox({
    required TextEditingController controller,
    required bool bad,
    required bool isHour,
    required Color border,
    required Color text,
    required Color sub,
  }) {
    final err = Theme.of(context).colorScheme.error;
    Widget arrow(IconData icon, int delta) => SizedBox(
      width: 84,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 24,
        color: sub,
        icon: Icon(icon),
        onPressed: () => _step(hour: isHour, delta: delta),
      ),
    );
    return Column(
      children: [
        arrow(Icons.keyboard_arrow_up_rounded, 1),
        SizedBox(
          width: 84,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            selectAllOnFocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
              _MaxValueFormatter(isHour ? 12 : 59),
            ],
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w500,
              fontSize: 30,
            ),
            onChanged: (_) => _onTyped(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              // 비었거나 틀린 칸은 마지막 올바른 값으로 되돌린다.
              if (_problem != null) setState(_syncFields);
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: bad ? err : border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: bad ? err : AppColors.gradStart,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        arrow(Icons.keyboard_arrow_down_rounded, -1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + bottom + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '언제 고정할까요?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final (label, time) in _quickPicks())
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(label),
                        onPressed: () => _jumpTo(time),
                        side: BorderSide(color: border),
                        backgroundColor: Colors.transparent,
                        labelStyle: TextStyle(
                          color: AppColors.gradStart,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _itemExtent * 3,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: AppColors.gradStart.withAlpha(isDark ? 28 : 18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _dayCtrl,
                    itemExtent: _itemExtent,
                    diameterRatio: 1.8,
                    perspective: 0.003,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: _onDayWheel,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _dayCount,
                      builder: (_, i) => Center(
                        child: Text(
                          _dayLabel(i),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ampmToggle(border, subColor),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _timeBox(
                  controller: _hourCtrl,
                  bad: _hourBad,
                  isHour: true,
                  border: border,
                  text: textColor,
                  sub: subColor,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                      color: subColor,
                    ),
                  ),
                ),
                _timeBox(
                  controller: _minCtrl,
                  bad: _minBad,
                  isHour: false,
                  border: border,
                  text: textColor,
                  sub: subColor,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canConfirm ? AppColors.brandGradient : null,
                  color: _canConfirm ? null : border,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: _canConfirm
                      ? () => Navigator.pop(context, _selected)
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: subColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _confirmLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
