import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 예약 시각을 고르는 하단 시트. 확인하면 고른 시각을, 닫으면 null을 돌려준다.
/// [initial]을 주면 그 시각으로 미리 맞춰 둔다(미래이고 선택 범위 안일 때만, 아니면 기본값).
Future<DateTime?> showScheduleSheet(BuildContext context, {DateTime? initial}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ScheduleSheet(initial: initial),
  );
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _dayCount = 60;

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
  late DateTime _selected = _initialSelection();

  late final _dayCtrl = FixedExtentScrollController(initialItem: _dayIndex);
  late final _ampmCtrl = FixedExtentScrollController(initialItem: _ampm);
  late final _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
  late final _minCtrl = FixedExtentScrollController(initialItem: _selected.minute);

  DateTime _initialSelection() {
    final now = DateTime.now();
    final wanted = widget.initial;
    if (wanted != null && wanted.isAfter(now)) {
      final days = _dateOnly(wanted).difference(_dateOnly(now)).inDays;
      if (days < _dayCount) {
        return DateTime(wanted.year, wanted.month, wanted.day, wanted.hour, wanted.minute);
      }
    }
    final t = now.add(const Duration(minutes: 10));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute);
  }

  int get _dayIndex => _dateOnly(_selected).difference(_today).inDays;
  int get _ampm => _selected.hour >= 12 ? 1 : 0;
  int get _hour12 => _selected.hour % 12 == 0 ? 12 : _selected.hour % 12;

  bool get _isFuture => _selected.isAfter(DateTime.now());

  @override
  void dispose() {
    _dayCtrl.dispose();
    _ampmCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  /// 휠이 바꾼 값들을 모아 [_selected]를 다시 만든다.
  void _fromWheels() {
    final day = _today.add(Duration(days: _dayCtrl.selectedItem.clamp(0, _dayCount - 1)));
    final hour12 = (_hourCtrl.selectedItem % 12) + 1; // 1..12
    final hour = (hour12 % 12) + 12 * _ampmCtrl.selectedItem.clamp(0, 1);
    setState(() {
      _selected = DateTime(day.year, day.month, day.day, hour, _minCtrl.selectedItem % 60);
    });
  }

  /// 빠른 선택 칩: 값을 정하고 휠을 그 자리로 굴린다.
  void _jumpTo(DateTime t) {
    setState(() => _selected = DateTime(t.year, t.month, t.day, t.hour, t.minute));
    const d = Duration(milliseconds: 250);
    const c = Curves.easeOut;
    _dayCtrl.animateToItem(_dayIndex.clamp(0, _dayCount - 1), duration: d, curve: c);
    _ampmCtrl.animateToItem(_ampm, duration: d, curve: c);
    _hourCtrl.animateToItem(_nearest(_hourCtrl, _hour12 - 1, 12), duration: d, curve: c);
    _minCtrl.animateToItem(_nearest(_minCtrl, _selected.minute, 60), duration: d, curve: c);
  }

  /// 순환 휠에서 [target] 값에 가장 가까운 절대 인덱스.
  int _nearest(FixedExtentScrollController ctrl, int target, int count) {
    final cur = ctrl.selectedItem;
    var delta = (target - cur % count) % count;
    if (delta > count / 2) delta -= count;
    return cur + delta;
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
    picks.add(('내일 아침 8시', DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8)));
    return picks;
  }

  String _dayLabel(int i) {
    final d = _today.add(Duration(days: i));
    final wd = _weekdays[d.weekday - 1];
    if (i == 0) return '오늘';
    if (i == 1) return '내일';
    return '${d.month}월 ${d.day}일 ($wd)';
  }

  String _summary() {
    final diff = _dateOnly(_selected).difference(_today).inDays;
    final day = diff == 0
        ? '오늘'
        : diff == 1
            ? '내일'
            : '${_selected.month}월 ${_selected.day}일 (${_weekdays[_selected.weekday - 1]})';
    final m = _selected.minute.toString().padLeft(2, '0');
    return '$day ${_ampm == 0 ? '오전' : '오후'} $_hour12:$m';
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
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          Text('언제 고정할까요?',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
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
                          fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _itemExtent * 5,
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
                _wheelsFor(isDark, textColor, subColor),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: _isFuture ? AppColors.brandGradient : null,
                color: _isFuture ? null : border,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextButton(
                onPressed: _isFuture ? () => Navigator.pop(context, _selected) : null,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: subColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isFuture ? '${_summary()}에 고정' : '지난 시각이에요',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _wheelsCache;
  bool? _wheelsDark;

  /// 휠은 시각이 바뀔 때마다 다시 만들 필요가 없어서(선택은 컨트롤러가 들고 있다)
  /// 한 번 만든 위젯을 재사용한다. 그래야 스크롤 중 프레임이 끊기지 않는다.
  Widget _wheelsFor(bool isDark, Color textColor, Color subColor) {
    if (_wheelsCache != null && _wheelsDark == isDark) return _wheelsCache!;
    _wheelsDark = isDark;
    return _wheelsCache = RepaintBoundary(
      child:
        Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _wheel(
                    controller: _dayCtrl,
                    count: _dayCount,
                    label: _dayLabel,
                    color: textColor,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _wheel(
                    controller: _ampmCtrl,
                    count: 2,
                    label: (i) => i == 0 ? '오전' : '오후',
                    color: textColor,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _wheel(
                    controller: _hourCtrl,
                    count: 12,
                    loop: true,
                    label: (i) => '${i + 1}',
                    color: textColor,
                  ),
                ),
                Text(':',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: subColor)),
                Expanded(
                  flex: 2,
                  child: _wheel(
                    controller: _minCtrl,
                    count: 60,
                    loop: true,
                    label: (i) => i.toString().padLeft(2, '0'),
                    color: textColor,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int) label,
    required Color color,
    bool loop = false,
  }) {
    Widget item(int i) => Center(
          child: Text(
            label(i),
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: color),
          ),
        );
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _itemExtent,
      diameterRatio: 1.8,
      perspective: 0.003,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (_) => _fromWheels(),
      childDelegate: loop
          ? ListWheelChildLoopingListDelegate(
              children: [for (var i = 0; i < count; i++) item(i)])
          : ListWheelChildBuilderDelegate(
              childCount: count, builder: (_, i) => item(i)),
    );
  }
}
