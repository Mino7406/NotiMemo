import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../storage/ai_storage.dart';
import '../storage/settings_storage.dart';
import '../theme/app_theme.dart';
import '../utils/reminder_time.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_toast.dart';

// 설정 화면: 테마, 진동, AI 사용, 앱 정보
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
  // 앱 버전(앱 정보에 표시)
  String _version = '';
  // 업데이트 확인 중에 버튼이 중복으로 눌리지 않게 하는 표시
  bool _checkingUpdate = false;
  late ThemeMode _currentMode;
  // AI 기능 동의 여부
  bool _aiOn = false;
  bool _autoClassify = true;
  // AI가 알림 시각을 일정보다 앞당기는 분(기본 30)
  int _leadMinutes = defaultLeadMinutes;
  bool _vibration = true;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.currentMode;
    _loadVersion();
    _loadAi();
  }

  /// 최신 버전을 확인해서 새 버전이 있으면 안내 창을, 아니면 결과를 토스트로 알린다.
  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    final result = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    switch (result.status) {
      case UpdateStatus.available:
        showUpdateDialog(context, result.version!);
      case UpdateStatus.upToDate:
        showAppToast(context, '최신 버전을 사용하고 있어요.');
      case UpdateStatus.failed:
        showAppToast(
          context,
          '업데이트를 확인하지 못했어요. 인터넷 연결을 확인해 주세요.',
          isError: true,
        );
    }
  }

  // 저장된 AI·진동 설정을 읽어서 화면에 반영한다
  Future<void> _loadAi() async {
    final consent = await AiStorage.getConsent();
    final lead = await AiStorage.getLeadMinutes();
    final classify = await AiStorage.getAutoClassify();
    final vibration = await SettingsStorage.getVibration();
    if (mounted) {
      setState(() {
        _vibration = vibration;
        _aiOn = consent == true;
        _leadMinutes = lead;
        _autoClassify = classify;
      });
    }
  }

  // 진동을 켜고 끈다. 켜는 순간 한 번 진동해서 느낌을 보여준다
  Future<void> _setVibration(bool on) async {
    await SettingsStorage.setVibration(on);
    if (mounted) setState(() => _vibration = on);
    if (on) NotificationService.vibrate(); // 켜자마자 느낌을 보여 준다
  }

  Future<void> _setAutoClassify(bool on) async {
    await AiStorage.setAutoClassify(on);
    if (mounted) setState(() => _autoClassify = on);
  }

  Future<void> _setLead(int minutes) async {
    await AiStorage.setLeadMinutes(minutes);
    if (mounted) setState(() => _leadMinutes = minutes);
  }

  // 여유 시간을 직접 입력하는 창을 연다
  Future<void> _askCustomLead() async {
    final minutes = await showLeadTimeDialog(
      context,
      initial: _leadMinutes,
      max: AiStorage.maxLeadMinutes,
    );
    if (minutes != null) await _setLead(minutes);
  }

  /// 켤 때는 메모가 외부로 전송된다는 안내와 동의를 먼저 받는다. 끌 때는 바로 끈다.
  Future<void> _toggleAi(bool on) async {
    if (!on) {
      await AiStorage.setConsent(false);
      if (mounted) setState(() => _aiOn = false);
      return;
    }
    final agreed = await showAiConsentDialog(context);
    if (agreed == null || !mounted) return;
    await AiStorage.setConsent(agreed);
    if (mounted) setState(() => _aiOn = agreed);
  }

  // 패키지 정보에서 앱 버전을 읽어 온다
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  // 테마를 바꾸면 화면에 바로 반영하고 앱 전체에도 알려준다
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
                    _SectionLabel(label: '진동', subColor: subColor),
                    const SizedBox(height: 10),
                    _AiSwitchCard(
                      switchKey: const Key('vibration-switch'),
                      title: '알림 진동',
                      onText: '알림을 고정하거나 예약을 걸거나 다시 게시할 때 진동해요.',
                      offText: '꺼져 있어요. 진동하지 않아요.',
                      value: _vibration,
                      onChanged: _setVibration,
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'AI 기능 켜기', subColor: subColor),
                    const SizedBox(height: 10),
                    _AiSwitchCard(
                      switchKey: const Key('ai-switch'),
                      title: 'AI로 메모 정리하기',
                      onText: '✨ 버튼을 누르면 메모가 외부 서버(Cloudflare)로 전송돼요.',
                      offText: '꺼져 있어요. 인터넷 없이 되는 기본 분석을 써요.',
                      value: _aiOn,
                      onChanged: _toggleAi,
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    if (_aiOn) ...[
                      const SizedBox(height: 24),
                      _SectionLabel(label: 'AI 설정', subColor: subColor),
                      const SizedBox(height: 10),
                      _AiSwitchCard(
                        switchKey: const Key('auto-classify-switch'),
                        title: '자동 분류 시스템',
                        onText: '메모의 카테고리·우선순위·요약을 자동으로 정리해요.',
                        offText: '꺼져 있어요. ✨은 메모의 예약 시각만 찾고, 메모는 전송하지 않아요.',
                        value: _autoClassify,
                        onChanged: _setAutoClassify,
                        isDark: isDark,
                        textColor: textColor,
                        subColor: subColor,
                      ),
                      const SizedBox(height: 10),
                      _AiLeadCard(
                        minutes: _leadMinutes,
                        onSelect: _setLead,
                        onCustom: _askCustomLead,
                        isDark: isDark,
                        textColor: textColor,
                        subColor: subColor,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _SectionLabel(label: '앱 정보', subColor: subColor),
                    const SizedBox(height: 10),
                    _AppInfoCard(
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                      version: _version,
                      checkingUpdate: _checkingUpdate,
                      onCheckUpdate: _checkUpdate,
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Text(
                        'made by Mino7406, VVYUNS',
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

// 설정 묶음 위에 붙는 작은 제목
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

const _contactEmail = 'rlaalsgh7406@gmail.com';

// 앱 정보 카드(버전, 업데이트 확인, 문의, 업데이트 날짜)
class _AppInfoCard extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final String version;
  final bool checkingUpdate;
  final VoidCallback onCheckUpdate;

  const _AppInfoCard({
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.version,
    required this.checkingUpdate,
    required this.onCheckUpdate,
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
                    key: const Key('check-update'),
                    onTap: checkingUpdate ? null : onCheckUpdate,
                    child: Text(
                      checkingUpdate ? '확인 중...' : '업데이트 확인',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gradStart,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: dividerColor,
            ),
            _InfoRow(
              label: '문의',
              textColor: textColor,
              subColor: subColor,
              trailing: GestureDetector(
                key: const Key('contact-email'),
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: _contactEmail));
                  showAppToast(context, '이메일 주소를 복사했어요.');
                },
                child: const Text(
                  _contactEmail,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.gradStart,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: dividerColor,
            ),
            _InfoRow(
              label: '업데이트',
              textColor: textColor,
              subColor: subColor,
              trailing: Text(
                // 릴리스할 때마다 그 날짜로 고친다
                '2026.10.03',
                style: TextStyle(fontSize: 14, color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 앱 정보 카드 안의 한 줄(왼쪽 이름, 오른쪽 내용)
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
            child: Text(label, style: TextStyle(fontSize: 14, color: subColor)),
          ),
          Expanded(child: trailing),
        ],
      ),
    );
  }
}

// 시스템/라이트/다크 중 하나를 고르는 카드
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

  // 고를 수 있는 테마 목록
  static const _options = [
    (
      mode: ThemeMode.system,
      label: '시스템 기본',
      icon: Icons.brightness_auto_rounded,
    ),
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
                      horizontal: 16,
                      vertical: 15,
                    ),
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
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// 켜고 끄는 설정 카드(AI 기능, 자동 분류). 꺼져 있어도 기본(오프라인) 분석은 쓸 수 있다.
class _AiSwitchCard extends StatelessWidget {
  final Key switchKey;
  final String title;
  final String onText;
  final String offText;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _AiSwitchCard({
    required this.switchKey,
    required this.title,
    required this.onText,
    required this.offText,
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value ? onText : offText,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gradStart,
          ),
        ],
      ),
    );
  }
}

/// AI가 제안하는 예약 알림을 일정보다 얼마나 앞당길지 고르는 카드.
class _AiLeadCard extends StatelessWidget {
  // 빠르게 고를 수 있는 여유 시간(분). 이 값이 아니면 직접 입력한 값으로 본다
  static const _presets = [0, 5, 10, 30, 60, 120];

  final int minutes;
  final ValueChanged<int> onSelect;
  final VoidCallback onCustom;
  final bool isDark;
  final Color textColor;
  final Color subColor;

  const _AiLeadCard({
    required this.minutes,
    required this.onSelect,
    required this.onCustom,
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });

  static String _label(int m) =>
      m == 0 ? '안 함' : leadLabel(Duration(minutes: m))!;

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final isCustom = !_presets.contains(minutes);
    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.gradStart.withAlpha(40),
      side: BorderSide(color: selected ? AppColors.gradStart : border),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.gradStart : textColor,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '여유 시간',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            minutes == 0
                ? 'AI가 찾은 일정 시각에 딱 맞춰 알려요.'
                : 'AI가 찾은 일정 시각보다 ${_label(minutes)}에 알려요.',
            style: TextStyle(fontSize: 12.5, color: subColor, height: 1.45),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                chip(_label(m), minutes == m, () => onSelect(m)),
              chip(
                isCustom ? '직접: ${_label(minutes)}' : '직접 설정',
                isCustom,
                onCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
