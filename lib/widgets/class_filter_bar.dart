import 'package:flutter/material.dart';
import '../models/memo_entry.dart';
import '../theme/app_theme.dart';
import '../utils/analysis_labels.dart';
import '../utils/class_filter.dart';

/// 알림 내역·예약 목록 위에 붙는 분류/우선순위 필터 칩 줄.
/// 항목이 2개 미만이거나 분류된 항목이 없으면 아무것도 그리지 않는다.
class ClassFilterBar extends StatelessWidget {
  final List<({String? category, MemoPriority priority})> items;
  final ClassFilter filter;
  final ValueChanged<ClassFilter> onChanged;
  final bool isDark;
  final Color subColor;

  const ClassFilterBar({
    super.key,
    required this.items,
    required this.filter,
    required this.onChanged,
    required this.isDark,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoriesIn(items.map((e) => e.category));
    if (items.length < 2 || categories.isEmpty) return const SizedBox.shrink();

    final priorities = [
      for (final p in MemoPriority.values.reversed) // 높음 → 보통 → 낮음
        if (items.any((e) => e.priority == p)) p,
    ];
    int countCat(String c) => items.where((e) => e.category == c).length;
    int countPri(MemoPriority p) => items.where((e) => e.priority == p).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(
            label: '분류',
            subColor: subColor,
            chips: [
              _FilterChip(
                keyName: 'filter-cat-all',
                label: '전체 ${items.length}',
                selected: filter.category == null,
                isDark: isDark,
                onTap: () => onChanged(filter.withCategory(null)),
              ),
              for (final c in categories)
                _FilterChip(
                  keyName: 'filter-cat-$c',
                  label: '$c ${countCat(c)}',
                  selected: filter.category == c,
                  isDark: isDark,
                  onTap: () => onChanged(filter.withCategory(c)),
                ),
            ],
          ),
          if (priorities.length >= 2) ...[
            const SizedBox(height: 6),
            _Row(
              label: '우선순위',
              subColor: subColor,
              chips: [
                _FilterChip(
                  keyName: 'filter-pri-all',
                  label: '전체',
                  selected: filter.priority == null,
                  isDark: isDark,
                  onTap: () => onChanged(filter.withPriority(null)),
                ),
                for (final p in priorities)
                  _FilterChip(
                    keyName: 'filter-pri-${p.name}',
                    label: '${priorityLabel(p)} ${countPri(p)}',
                    selected: filter.priority == p,
                    isDark: isDark,
                    onTap: () => onChanged(filter.withPriority(p)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final Color subColor;
  final List<Widget> chips;
  const _Row({
    required this.label,
    required this.subColor,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: subColor,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in chips)
                  Padding(padding: const EdgeInsets.only(right: 6), child: c),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String keyName;
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    return GestureDetector(
      key: Key(keyName),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gradStart.withAlpha(isDark ? 50 : 30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.gradStart.withAlpha(isDark ? 160 : 130)
                : border,
            width: 1.3,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppColors.gradStart
                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
          ),
        ),
      ),
    );
  }
}
