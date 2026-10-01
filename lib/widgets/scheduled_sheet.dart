import 'package:flutter/material.dart';
import '../models/memo_entry.dart';
import '../models/scheduled_note.dart';
import '../services/notification_service.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';
import '../utils/analysis_labels.dart';
import '../utils/time_format.dart';

/// 예약된 메모 목록 시트(알림 내역과 같은 하단 시트). 항목을 누르면 닫히면서 그 예약을
/// 돌려줘서 홈 화면 입력창에서 고칠 수 있게 한다. 닫으면 null.
Future<ScheduledNote?> showScheduledSheet(BuildContext context) {
  return showModalBottomSheet<ScheduledNote>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ScheduledSheet(),
  );
}

class _ScheduledSheet extends StatefulWidget {
  const _ScheduledSheet();

  @override
  State<_ScheduledSheet> createState() => _ScheduledSheetState();
}

class _ScheduledSheetState extends State<_ScheduledSheet> {
  List<ScheduledNote>? _items;

  /// 예약 메모와 같은 id의 히스토리 기록(카테고리·우선순위 표시용).
  Map<String, MemoEntry> _entries = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await MemoStorage.getScheduled();
    final entries = await MemoStorage.getList();
    if (mounted) {
      setState(() {
        _items = items;
        _entries = {for (final e in entries) e.id: e};
      });
    }
  }

  Future<void> _cancel(ScheduledNote note) async {
    await NotificationService.cancelSchedule(note.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final items = _items;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '예약 목록',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (items != null && items.isNotEmpty) ...[
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
                      '${items.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items == null)
            const SizedBox(height: 80)
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 52,
                    color: subColor.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '예약된 메모가 없어요',
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
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final note = items[i];
                  return Dismissible(
                    key: ValueKey(note.id),
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
                    onDismissed: (_) => _cancel(note),
                    child: Material(
                      color: isDark
                          ? AppColors.elevatedDark
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context, note),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (b) =>
                                    AppColors.brandGradient.createShader(b),
                                child: const Icon(
                                  Icons.schedule_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_entries[note.id] != null &&
                                        classLabel(_entries[note.id]!) !=
                                            null) ...[
                                      Text(
                                        classLabel(_entries[note.id]!)!,
                                        key: Key('scheduled-label-${note.id}'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.gradStart,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      note.memo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatEntryTime(note.at),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subColor.withAlpha(160),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '예약 취소',
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: subColor,
                                ),
                                onPressed: () => _cancel(note),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
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
