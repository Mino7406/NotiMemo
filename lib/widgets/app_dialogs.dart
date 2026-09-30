import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

/// 공통 다이얼로그 레이아웃: 그라데이션 아이콘 + 제목 + 본문 + 버튼 행.
class _AppDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> body;
  final List<Widget> Function(Color subColor) actions;

  const _AppDialog({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...body,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions(subColor),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _cancelButton(BuildContext ctx, Color subColor, String label, [bool? result]) {
  return TextButton(
    onPressed: () => Navigator.pop(ctx, result),
    style: TextButton.styleFrom(foregroundColor: subColor),
    child: Text(label),
  );
}

Widget _confirmButton(String label, VoidCallback onPressed) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: AppColors.gradStart),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

TextStyle _bodyStyle(Color color) =>
    TextStyle(fontSize: 14, color: color, height: 1.6);

void showUpdateDialog(BuildContext context, String version) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  showDialog(
    context: context,
    builder: (ctx) => _AppDialog(
      icon: Icons.system_update_rounded,
      title: '업데이트 알림',
      body: [
        Text(
          'v$version 버전이 출시되었습니다.\n지금 업데이트하시겠어요?',
          style: _bodyStyle(subColor),
        ),
      ],
      actions: (subColor) => [
        _cancelButton(ctx, subColor, '나중에'),
        const SizedBox(width: 8),
        _confirmButton('업데이트', () {
          Navigator.pop(ctx);
          launchUrl(
            Uri.parse(UpdateService.releasesUrl),
            mode: LaunchMode.externalApplication,
          );
        }),
      ],
    ),
  );
}

Future<bool> showRestoreConfirmDialog(BuildContext context, String memo) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : const Color(0xFF111827);
  final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AppDialog(
      icon: Icons.push_pin_rounded,
      title: '알림 재생성',
      body: [
        Text('이 메모로 알림을 다시 고정할까요?', style: _bodyStyle(subColor)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.elevatedDark : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Text(
            memo,
            style: TextStyle(fontSize: 13.5, color: textColor, height: 1.5),
          ),
        ),
      ],
      actions: (subColor) => [
        _cancelButton(ctx, subColor, '취소', false),
        const SizedBox(width: 8),
        _confirmButton('재생성', () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return confirmed ?? false;
}
