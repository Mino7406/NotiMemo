import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final void Function(ThemeMode) onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  late ThemeMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.currentMode;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  void _changeTheme(ThemeMode mode) {
    setState(() => _currentMode = mode);
    widget.onThemeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(label: '테마', subColor: subColor),
                    const SizedBox(height: 10),
                    _ThemePicker(
                      currentMode: _currentMode,
                      onChanged: _changeTheme,
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: '앱 정보', subColor: subColor),
                    const SizedBox(height: 10),
                    _AppInfoCard(
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                      version: _version,
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Text(
                        'made by Mino7406',
                        style: TextStyle(
                          fontSize: 12,
                          color: subColor.withAlpha(120),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color subColor;
  const _SectionLabel({required this.label, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: subColor,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _AppInfoCard extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final String version;

  const _AppInfoCard({
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.version,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

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
          children: [
            _InfoRow(
              label: '앱 이름',
              textColor: textColor,
              subColor: subColor,
              trailing: Text(
                '알림메모',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
            Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: dividerColor),
            _InfoRow(
              label: '버전',
              textColor: textColor,
              subColor: subColor,
              trailing: Row(
                children: [
                  Text(
                    version.isEmpty ? '...' : version,
                    style: TextStyle(fontSize: 14, color: textColor),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse(UpdateService.releasesUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      '업데이트 확인',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gradStart,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: dividerColor),
            _InfoRow(
              label: '제공',
              textColor: textColor,
              subColor: subColor,
              trailing: Text(
                'Mino7406',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color subColor;
  final Widget trailing;

  const _InfoRow({
    required this.label,
    required this.textColor,
    required this.subColor,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: subColor,
              ),
            ),
          ),
          Expanded(child: trailing),
        ],
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
