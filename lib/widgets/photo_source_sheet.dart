import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';

/// 사진을 어디서 가져올지 고르는 하단 시트. 취소하면 null.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PhotoSourceSheet(),
  );
}

// 카메라/갤러리 중 하나를 고르는 시트 모양
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '사진으로 메모 가져오기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SourceTile(
            icon: Icons.photo_camera_outlined,
            label: '카메라로 촬영',
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
            onTap: () => Navigator.pop(context, PhotoSource.camera),
          ),
          const SizedBox(height: 8),
          _SourceTile(
            icon: Icons.photo_library_outlined,
            label: '갤러리에서 선택',
            textColor: textColor,
            subColor: subColor,
            isDark: isDark,
            onTap: () => Navigator.pop(context, PhotoSource.gallery),
          ),
        ],
      ),
    );
  }
}

// 시트 안의 한 줄짜리 선택 버튼
class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color subColor;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.subColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.elevatedDark : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: subColor),
            ],
          ),
        ),
      ),
    );
  }
}
