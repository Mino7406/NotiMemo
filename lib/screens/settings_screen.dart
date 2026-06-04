import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  final ThemeMode currentMode;
  final void Function(ThemeMode) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '설정',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '화면 테마',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subColor,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            _ThemePicker(
              currentMode: currentMode,
              onChanged: onThemeChanged,
              isDark: isDark,
              textColor: textColor,
              subColor: subColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  final ThemeMode currentMode;
  final void Function(ThemeMode) onChanged;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _ThemePicker({
    required this.currentMode,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  static const _options = [
    (mode: ThemeMode.system, label: '시스템 기본', icon: Icons.brightness_auto_rounded),
    (mode: ThemeMode.light, label: '라이트', icon: Icons.light_mode_rounded),
    (mode: ThemeMode.dark, label: '다크', icon: Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: List.generate(_options.length, (i) {
            final opt = _options[i];
            final isSelected = currentMode == opt.mode;
            final isLast = i == _options.length - 1;

            return Column(
              children: [
                InkWell(
                  onTap: () => onChanged(opt.mode),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    child: Row(
                      children: [
                        Icon(
                          opt.icon,
                          size: 20,
                          color: isSelected ? AppColors.gradStart : subColor,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? textColor : subColor,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          ShaderMask(
                            shaderCallback: (b) =>
                                AppColors.brandGradient.createShader(b),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 48,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
