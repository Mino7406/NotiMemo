import 'package:flutter/material.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

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
  late List<MemoEntry> _list;

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
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
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
                  TextButton(
                    onPressed: () async {
                      await widget.onClearAll();
                      setState(() => _list.clear());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      '전체삭제',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: _list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Dismissible(
                  key: ValueKey(_list[i].time),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.white, size: 20),
                  ),
                  onDismissed: (_) async {
                    await widget.onDelete(i);
                    setState(() => _list.removeAt(i));
                  },
                  child: Material(
                    color: isDark ? AppColors.elevatedDark : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        final entry = _list[i];
                        Navigator.pop(context);
                        widget.onRestore(entry);
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (b) =>
                                  AppColors.brandGradient.createShader(b),
                              child: const Icon(
                                Icons.push_pin_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _list[i].memo,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      height: 1.45,
                                    ),
                                  ),
                                  if (_list[i].time != 0) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      formatEntryTime(_list[i].time),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withAlpha(160),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(Icons.replay_rounded, size: 14, color: subColor.withAlpha(120)),
                            const SizedBox(width: 2),
                            IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: subColor),
                              onPressed: () async {
                                await widget.onDelete(i);
                                setState(() => _list.removeAt(i));
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: bottomPad + 20),
        ],
      ),
    );
  }
}
