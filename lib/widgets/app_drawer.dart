import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'memo_list_row.dart';

/// 오른쪽에서 밀려 나오는 메뉴. 홈 화면의 보조 기능(AI 정리, 사진, 예약, 목록, 설정, 튜토리얼)을 모았다.
/// 항목을 누르면 메뉴를 닫고 동작을 실행한다.
class AppMenuDrawer extends StatelessWidget {
  final int scheduledCount;
  final int historyCount;
  final bool isBusy;
  final VoidCallback onAnalyze;
  final VoidCallback onPhoto;
  final VoidCallback onSchedule;
  final VoidCallback onScheduledList;
  final VoidCallback onHistory;
  final VoidCallback onSettings;
  final VoidCallback onTutorial;

  const AppMenuDrawer({
    super.key,
    required this.scheduledCount,
    required this.historyCount,
    required this.isBusy,
    required this.onAnalyze,
    required this.onPhoto,
    required this.onSchedule,
    required this.onScheduledList,
    required this.onHistory,
    required this.onSettings,
    required this.onTutorial,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    /// 메뉴를 닫은 뒤 [action]을 실행하는 탭 핸들러.
    VoidCallback run(VoidCallback action) => () {
      Navigator.pop(context);
      action();
    };

    Widget item({
      Key? key,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      int? count,
    }) {
      return InkWell(
        key: key,
        borderRadius: BorderRadius.circular(14),
        onTap: run(onTap),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.gradStart.withAlpha(isDark ? 36 : 24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.gradStart),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (count != null && count > 0)
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
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: subColor,
          letterSpacing: 0.3,
        ),
      ),
    );

    return Drawer(
      width: 300,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '알림메모',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  OutlinedIconAction(
                    key: const Key('menu-close'),
                    icon: Icons.close_rounded,
                    tooltip: '닫기',
                    size: 40,
                    isDark: isDark,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                children: [
                  section('메모 입력'),
                  item(
                    key: const Key('analyze-button'),
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI 자동 정리',
                    onTap: isBusy ? () {} : onAnalyze,
                  ),
                  item(
                    icon: Icons.photo_camera_outlined,
                    label: '사진으로 메모 입력',
                    onTap: isBusy ? () {} : onPhoto,
                  ),
                  section('예약'),
                  item(
                    key: const Key('menu-schedule'),
                    icon: Icons.schedule_rounded,
                    label: '예약 생성',
                    onTap: onSchedule,
                  ),
                  item(
                    key: const Key('menu-scheduled-list'),
                    icon: Icons.event_note_rounded,
                    label: '예약 목록',
                    count: scheduledCount,
                    onTap: onScheduledList,
                  ),
                  section('기록'),
                  item(
                    key: const Key('menu-history'),
                    icon: Icons.history_rounded,
                    label: '알림 내역',
                    count: historyCount,
                    onTap: onHistory,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Divider(height: 1, color: border),
                  ),
                  item(
                    key: const Key('menu-settings'),
                    icon: Icons.settings_outlined,
                    label: '설정',
                    onTap: onSettings,
                  ),
                  item(
                    key: const Key('menu-tutorial'),
                    icon: Icons.play_circle_outline_rounded,
                    label: '튜토리얼',
                    onTap: onTutorial,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
