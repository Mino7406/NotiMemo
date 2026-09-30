import 'package:flutter/material.dart';
import '../models/scheduled_note.dart';
import '../services/notification_service.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';

/// 예약된 메모 목록. 항목을 누르면 예약을 취소하고 그 메모를 [Navigator.pop]으로
/// 돌려줘서 홈 화면 입력창에서 고칠 수 있게 한다.
class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({super.key});

  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

class _ScheduledScreenState extends State<ScheduledScreen> {
  List<ScheduledNote>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await MemoStorage.getScheduled();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _cancel(ScheduledNote note) async {
    await NotificationService.cancelSchedule(note.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('예약 목록'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: items == null
          ? const SizedBox.shrink()
          : items.isEmpty
              ? Center(
                  child: Text('예약된 메모가 없어요',
                      style: TextStyle(color: subColor, fontSize: 15)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final note = items[i];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => Navigator.pop(context, note),
                        title: Text(
                          note.memo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 14, color: AppColors.gradStart),
                              const SizedBox(width: 4),
                              Text(formatEntryTime(note.at),
                                  style: TextStyle(color: subColor)),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: '예약 취소',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => _cancel(note),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
