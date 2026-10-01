import 'package:flutter/material.dart';
import '../storage/tutorial_storage.dart';
import '../theme/app_theme.dart';

/// 처음 실행할 때 한 번 보여주는 전체 화면 튜토리얼(은행 앱 온보딩처럼 한 장씩 넘긴다).
/// 메뉴의 `튜토리얼`로 다시 볼 수 있다. 끝나거나 건너뛰면 닫히고, [firstRun]이면 본 것으로 기록한다.
class TutorialScreen extends StatefulWidget {
  /// 처음 실행으로 열렸는지. true일 때만 끝난 뒤 `tutorial_seen`을 저장한다.
  final bool firstRun;
  const TutorialScreen({super.key, this.firstRun = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _Page {
  final String title;
  final String body;
  final Widget Function(bool isDark, Color textColor, Color subColor) art;
  const _Page(this.title, this.body, this.art);
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _ctrl = PageController();
  int _index = 0;

  static final _pages = <_Page>[
    _Page(
      '메모를 알림창에 고정해요',
      '메모를 쓰고 [알림 고정하기]를 누르면\n알림창에 남아서 언제든 확인할 수 있어요.',
      (d, t, s) => _NotificationArt(isDark: d, textColor: t, subColor: s),
    ),
    _Page(
      '사진과 AI로 빠르게 정리해요',
      '사진 속 글자를 읽어 메모로 옮기고,\n✨로 분류·요약·예약 시각까지 정리해요.',
      (d, t, s) => _AiArt(isDark: d, textColor: t, subColor: s),
    ),
    _Page(
      '원하는 시각에 알림이 떠요',
      '예약 생성으로 시각을 정하면 그때 고정돼요.\nAI는 일정보다 조금 앞서 알려 드려요.',
      (d, t, s) => _ScheduleArt(isDark: d, textColor: t, subColor: s),
    ),
    _Page(
      '알림창에서 바로 고치고 지워요',
      '앱을 열지 않아도 알림에서 [수정]하거나\n[지우기]로 정리할 수 있어요.',
      (d, t, s) => _ActionsArt(isDark: d, textColor: t, subColor: s),
    ),
    _Page(
      '더 많은 기능은 ☰ 메뉴에 있어요',
      '예약 목록, 알림 내역, 설정을\n오른쪽 위 메뉴에서 열 수 있어요.',
      (d, t, s) => _MenuArt(isDark: d, textColor: t, subColor: s),
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.firstRun) await TutorialStorage.setSeen();
    if (mounted) Navigator.pop(context);
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return PopScope(
      // 처음 실행에서는 뒤로 가기로 빠져나가도 본 것으로 기록한다.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.firstRun) TutorialStorage.setSeen();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                  child: AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: TextButton(
                      key: const Key('tutorial-skip'),
                      onPressed: _isLast ? null : _finish,
                      style: TextButton.styleFrom(foregroundColor: subColor),
                      child: const Text('건너뛰기'),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 260,
                            child: Center(
                              child: page.art(isDark, textColor, subColor),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              letterSpacing: -0.4,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            page.body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: subColor,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _index ? AppColors.gradStart : border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextButton(
                      key: const Key('tutorial-next'),
                      onPressed: _next,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isLast ? '시작하기' : '다음',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 일러스트: 이미지 파일 없이 앱 화면을 단순화해서 그린다(라이트/다크 모두 대응) ──

/// 알림 카드 모양의 흰 상자.
class _Card extends StatelessWidget {
  final bool isDark;
  final Widget child;
  final double? width;
  const _Card({required this.isDark, required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF667EEA).withAlpha(30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _GradIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const _GradIcon(this.icon, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

abstract class _Art extends StatelessWidget {
  final bool isDark;
  final Color textColor;
  final Color subColor;
  const _Art({
    required this.isDark,
    required this.textColor,
    required this.subColor,
  });
}

class _NotificationArt extends _Art {
  const _NotificationArt({
    required super.isDark,
    required super.textColor,
    required super.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      width: 280,
      child: Row(
        children: [
          const _GradIcon(Icons.push_pin_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('알림메모', style: TextStyle(fontSize: 12, color: subColor)),
                const SizedBox(height: 3),
                Text(
                  '내일 오후 3시 치과 예약',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiArt extends _Art {
  const _AiArt({
    required super.isDark,
    required super.textColor,
    required super.subColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, {bool accent = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gradStart.withAlpha(accent ? 40 : 22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.gradStart,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            _GradIcon(Icons.photo_camera_outlined, size: 54),
            SizedBox(width: 14),
            Icon(Icons.arrow_forward_rounded, color: AppColors.gradStart),
            SizedBox(width: 14),
            _GradIcon(Icons.auto_awesome_outlined, size: 54),
          ],
        ),
        const SizedBox(height: 22),
        _Card(
          isDark: isDark,
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '금요일 오후 3시 치과 예약 꼭 가기',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  chip('건강', accent: true),
                  chip('우선순위 높음'),
                  chip('금요일 3시'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScheduleArt extends _Art {
  const _ScheduleArt({
    required super.isDark,
    required super.textColor,
    required super.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Card(
          isDark: isDark,
          width: 280,
          child: Row(
            children: [
              const _GradIcon(Icons.schedule_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '10월 2일 (금) 오후 2:30',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '30분 전에 알려 드려요',
                      style: TextStyle(fontSize: 12.5, color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Icon(Icons.arrow_downward_rounded, color: AppColors.gradStart),
        const SizedBox(height: 14),
        _Card(
          isDark: isDark,
          width: 280,
          child: Row(
            children: [
              const _GradIcon(Icons.push_pin_rounded),
              const SizedBox(width: 12),
              Text(
                '오후 3시 치과 예약',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsArt extends _Art {
  const _ActionsArt({
    required super.isDark,
    required super.textColor,
    required super.subColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget action(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );

    return _Card(
      isDark: isDark,
      width: 290,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GradIcon(Icons.push_pin_rounded, size: 34),
              const SizedBox(width: 10),
              Text(
                '오후 3시 치과 예약',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              action('수정', Icons.edit_outlined, AppColors.gradStart),
              const SizedBox(width: 10),
              action('지우기', Icons.close_rounded, AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuArt extends _Art {
  const _MenuArt({
    required super.isDark,
    required super.textColor,
    required super.subColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.gradStart.withAlpha(30),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppColors.gradStart),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            children: [
              const _GradIcon(Icons.menu_rounded, size: 44),
              const SizedBox(height: 6),
              Icon(Icons.arrow_forward_rounded, color: AppColors.gradStart),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _Card(
          isDark: isDark,
          width: 190,
          child: Column(
            children: [
              row(Icons.event_note_rounded, '예약 목록'),
              row(Icons.history_rounded, '알림 내역'),
              row(Icons.settings_outlined, '설정'),
              row(Icons.play_circle_outline_rounded, '튜토리얼'),
            ],
          ),
        ),
      ],
    );
  }
}
