import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Widget _cancelButton(
  BuildContext ctx,
  Color subColor,
  String label, [
  bool? result,
]) {
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

/// 알림 내역에서 다시 고정할 때 고르는 방식.
enum RestoreChoice { now, schedule }

/// 알림 내역의 메모를 다시 고정할 방법을 묻는다. 취소하면 null.
Future<RestoreChoice?> showRestoreConfirmDialog(
  BuildContext context,
  String memo,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : const Color(0xFF111827);
  final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  return showDialog<RestoreChoice>(
    context: context,
    builder: (ctx) => _AppDialog(
      icon: Icons.push_pin_rounded,
      title: '알림 재생성',
      body: [
        Text('이 메모를 언제 고정할까요?', style: _bodyStyle(subColor)),
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
        _cancelButton(ctx, subColor, '취소'),
        _confirmButton(
          '예약해서 고정',
          () => Navigator.pop(ctx, RestoreChoice.schedule),
        ),
        _confirmButton('바로 고정', () => Navigator.pop(ctx, RestoreChoice.now)),
      ],
    ),
  );
}

/// AI 자동 정리를 처음 쓸 때 메모가 외부로 전송된다는 걸 알리고 동의를 받는다.
/// true = 동의하고 사용, false = AI 없이 사용(기본 분석), null = 닫음(아무것도 정하지 않음).
Future<bool?> showAiConsentDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? Colors.white : const Color(0xFF111827);
  final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  return showDialog<bool>(
    context: context,
    builder: (ctx) => _AppDialog(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 자동 정리',
      body: [
        Text('메모를 분류하고 요약하려면 메모 내용이 외부 서버로 전송돼요.', style: _bodyStyle(subColor)),
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
            '• 전송되는 것: 메모 글자(최대 500자)와 이 앱 설치를 구분하는 무작위 번호\n'
            '• 처리 서버: Cloudflare (AI 학습에 쓰이지 않고 저장되지 않아요)\n'
            '• 비밀번호·계좌번호 같은 민감한 내용은 넣지 마세요\n'
            '• 설정에서 언제든 끌 수 있어요',
            style: TextStyle(fontSize: 13, color: textColor, height: 1.55),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '동의하지 않아도 인터넷 없이 되는 기본 분석은 쓸 수 있어요.',
          style: TextStyle(fontSize: 12.5, color: subColor, height: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          '참고: VPN을 쓰는 중이면 AI 분석이 안 될 수 있어요. VPN을 끄거나 이 앱을 VPN 제외 앱에 추가해 보세요.',
          key: const Key('consent-note'),
          style: TextStyle(fontSize: 12, color: subColor, height: 1.5),
        ),
      ],
      actions: (sub) => [
        _cancelButton(ctx, sub, 'AI 없이 사용', false),
        const SizedBox(width: 8),
        _confirmButton('동의하고 사용', () => Navigator.pop(ctx, true)),
      ],
    ),
  );
}

/// 예약 알림 여유 시간(분)을 직접 입력받는다. 확인하면 분, 취소하면 null.
Future<int?> showLeadTimeDialog(
  BuildContext context, {
  required int initial,
  required int max,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _LeadTimeDialog(initial: initial, max: max),
  );
}

class _LeadTimeDialog extends StatefulWidget {
  final int initial;
  final int max;
  const _LeadTimeDialog({required this.initial, required this.max});

  @override
  State<_LeadTimeDialog> createState() => _LeadTimeDialogState();
}

class _LeadTimeDialogState extends State<_LeadTimeDialog> {
  late final _ctrl = TextEditingController(text: '${widget.initial}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  int? get _value {
    final v = int.tryParse(_ctrl.text);
    return v != null && v <= widget.max ? v : null;
  }

  void _submit() {
    final v = _value;
    if (v != null) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final err = Theme.of(context).colorScheme.error;
    final bad = _ctrl.text.isNotEmpty && _value == null;

    return _AppDialog(
      icon: Icons.schedule_rounded,
      title: '여유 시간 직접 설정',
      body: [
        Text(
          '일정 시각보다 몇 분 앞서 알릴지 정해요. 0이면 일정 시각에 딱 맞춰 알려요.',
          style: _bodyStyle(
            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: bad ? err : border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: bad ? err : AppColors.gradStart,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '분 전',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        if (bad)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(
                '0~${widget.max}분 사이로 입력하세요',
                style: TextStyle(fontSize: 12.5, color: err),
              ),
            ),
          ),
      ],
      actions: (subColor) => [
        _cancelButton(context, subColor, '취소'),
        _confirmButton('확인', _submit),
      ],
    );
  }
}
