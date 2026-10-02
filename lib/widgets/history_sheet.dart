import 'package:flutter/material.dart';
import '../models/memo_entry.dart';
import '../theme/app_theme.dart';
import '../utils/analysis_labels.dart';
import '../utils/class_filter.dart';
import 'app_dialogs.dart';
import 'class_filter_bar.dart';
import 'memo_list_row.dart';
import '../utils/time_format.dart';
import 'notice_button.dart';

// 알림 내역 시트. 삭제/다시 고정 같은 실제 처리는 홈 화면에서 넘겨받은 함수로 한다
class HistorySheet extends StatefulWidget {
  final List<MemoEntry> memoList;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onClearAll;
  final Future<void> Function(MemoEntry) onRestore;

  const HistorySheet({
    super.key,
    required this.memoList,
    required this.onDelete,
    required this.onClearAll,
    required this.onRestore,
  });

  @override
  State<HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<HistorySheet> {
  // 화면에 보여줄 내역(삭제하면 여기서도 바로 뺀다)
  late List<MemoEntry> _list;
  ClassFilter _filter = ClassFilter.none;

  // 필터에 쓰려고 분류·우선순위만 뽑는다
  ({String? category, MemoPriority priority}) _classOf(MemoEntry e) =>
      (category: e.category, priority: e.priority);

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.memoList);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final classItems = [for (final e in _list) _classOf(e)];
    final filter = _filter.normalizedFor(classItems);
    // 필터를 통과한 항목의 원래 위치 번호
    final shownIdx = visibleIndexes(_list, filter, _classOf);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '알림 내역',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_list.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_list.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_list.isNotEmpty)
                  ClearAllButton(
                    buttonKey: const Key('history-clear-all'),
                    isDark: isDark,
                    onPressed: () async {
                      final ok = await showClearAllDialog(
                        context,
                        count: _list.length,
                        filteredView: _filter.isActive,
                      );
                      if (!ok || !mounted) return;
                      await widget.onClearAll();
                      if (mounted) setState(() => _list.clear());
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClassFilterBar(
              items: classItems,
              filter: filter,
              onChanged: (f) => setState(() => _filter = f),
              isDark: isDark,
              subColor: subColor,
            ),
          ),
          // List or empty state
          if (_list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 52,
                    color: subColor.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '저장된 메모가 없어요',
                    style: TextStyle(color: subColor, fontSize: 15),
                  ),
                ],
              ),
            )
          else if (shownIdx.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                children: [
                  Text(
                    '조건에 맞는 메모가 없어요',
                    key: const Key('history-filter-empty'),
                    style: TextStyle(color: subColor, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  NoticeButton(
                    key: const Key('history-filter-reset'),
                    label: '필터 해제',
                    color: AppColors.gradStart,
                    onPressed: () => setState(() => _filter = ClassFilter.none),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: shownIdx.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, k) {
                  final i = shownIdx[k]; // 원래 목록에서의 위치(삭제·재생성에 사용)
                  void restore() {
                    final entry = _list[i];
                    Navigator.pop(context);
                    widget.onRestore(entry);
                  }

                  return Dismissible(
                    key: ValueKey(_list[i].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withAlpha(200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onDismissed: (_) async {
                      await widget.onDelete(i);
                      setState(() => _list.removeAt(i));
                    },
                    child: Material(
                      color: isDark
                          ? AppColors.elevatedDark
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      // 행 전체는 눌러도 아무 일도 없다. 재생성은 ↻ 버튼으로만 한다
                      // (스크롤하다 실수로 창이 열리는 것을 막기 위해).
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                          ),
                          child: MemoListRow(
                            icon: Icons.push_pin_rounded,
                            label: classLabel(_list[i]),
                            labelKey: Key('history-label-${_list[i].id}'),
                            memo: _list[i].memo,
                            timeText: _list[i].time != 0
                                ? formatEntryTime(_list[i].time)
                                : null,
                            textColor: textColor,
                            subColor: subColor,
                            actions: [
                              OutlinedIconAction(
                                key: Key('history-restore-${_list[i].id}'),
                                icon: Icons.replay_rounded,
                                tooltip: '다시 고정',
                                color: AppColors.gradStart,
                                isDark: isDark,
                                onTap: restore,
                              ),
                              OutlinedIconAction(
                                key: Key('history-delete-${_list[i].id}'),
                                icon: Icons.close_rounded,
                                tooltip: '삭제',
                                isDark: isDark,
                                onTap: () async {
                                  await widget.onDelete(i);
                                  setState(() => _list.removeAt(i));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: bottomPad + 20),
        ],
      ),
    );
  }
}
