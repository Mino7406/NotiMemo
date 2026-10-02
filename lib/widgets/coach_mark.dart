import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 코치마크 한 단계. [target] 키를 가진 위젯을 밝게 비추고 옆에 설명을 띄운다.
/// [target]이 없거나 화면에서 찾지 못하면 가운데 카드로 보여준다.
class CoachStep {
  final Key? target;
  final String title;
  final String body;

  /// 이 단계를 보여주기 직전에 실행한다(메뉴 열기, 샘플 글 넣기 등). 끝난 뒤 위치를 다시 잰다.
  final Future<void> Function()? onEnter;

  /// 이 단계를 떠날 때 실행한다(메뉴 닫기 등).
  final Future<void> Function()? onExit;

  /// 가운데 카드일 때 설명 위에 얹는 그림.
  final WidgetBuilder? art;

  /// true면 건너뛰기를 말풍선 왼쪽 아래 대신 왼쪽 위에 둔다(말풍선이 화면 아래쪽에 겹치는 큰 대상일 때).
  final bool skipAtTop;

  const CoachStep({
    this.target,
    required this.title,
    required this.body,
    this.onEnter,
    this.onExit,
    this.art,
    this.skipAtTop = false,
  });
}

/// 홈 화면 위에 어두운 막을 씌우고 [steps]를 차례로 안내한다. 끝나거나 건너뛰거나 뒤로 가면 닫히고 [onClose]를 부른다.
Future<void> showCoachMarks(
  BuildContext context, {
  required List<CoachStep> steps,
  Future<void> Function()? onClose,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => CoachMarkOverlay(steps: steps),
  );
  await onClose?.call();
}

/// 키가 [key]인 위젯의 화면상 영역. 못 찾으면 null.
Rect? findRectByKey(Key key) {
  Element? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.widget.key == key) {
      found = e;
      return;
    }
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  final ro = found?.renderObject;
  if (found == null || ro is! RenderBox || !ro.attached || !ro.hasSize) {
    return null;
  }
  // 스크롤 안에 가려져 있으면 보이는 위치로 옮긴다.
  try {
    Scrollable.ensureVisible(found!, duration: Duration.zero);
  } catch (_) {}
  return ro.localToGlobal(Offset.zero) & ro.size;
}

// 사용 방법 화면. 어두운 막 위에 말풍선을 올리고 단계를 넘기는 동작을 맡는다
class CoachMarkOverlay extends StatefulWidget {
  final List<CoachStep> steps;
  const CoachMarkOverlay({super.key, required this.steps});

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> {
  int _index = 0;
  Rect? _rect;
  bool _ready = false;
  // 단계를 바꾸는 중에 버튼이 연속으로 눌리는 것을 막는다
  bool _busy = false;
  // 대상의 위치가 바뀌는지 계속 지켜보는 타이머
  Timer? _track;

  bool get _isLast => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _enter();
    // 홈 화면의 입장 애니메이션·메뉴 열림 등으로 대상이 움직여도 구멍이 따라가도록 위치를 계속 다시 잰다.
    _track = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final key = widget.steps[_index].target;
      if (!mounted || !_ready || key == null) return;
      final r = findRectByKey(key);
      if (r != null && r != _rect) setState(() => _rect = r);
    });
  }

  @override
  void dispose() {
    _track?.cancel();
    super.dispose();
  }

  Future<void> _enter() async {
    final step = widget.steps[_index];
    setState(() => _ready = false);
    await step.onEnter?.call();
    // 메뉴가 열리거나 글이 들어간 뒤 레이아웃이 자리잡을 시간을 준다.
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;
    final key = step.target;
    setState(() {
      _rect = key == null ? null : findRectByKey(key);
      _ready = true;
    });
  }

  Future<void> _next() async {
    if (_busy) return;
    _busy = true;
    await widget.steps[_index].onExit?.call();
    if (_isLast) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    setState(() => _index++);
    await _enter();
    _busy = false;
  }

  Future<void> _prev() async {
    if (_busy || _index == 0) return;
    _busy = true;
    await widget.steps[_index].onExit?.call();
    if (!mounted) return;
    setState(() => _index--);
    await _enter();
    _busy = false;
  }

  Future<void> _skip() async {
    if (_busy) return;
    _busy = true;
    await widget.steps[_index].onExit?.call();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = widget.steps[_index];
    final size = MediaQuery.sizeOf(context);
    final rect = _rect?.inflate(6);
    final centered = rect == null;
    // 위·아래 중 말풍선이 들어갈 만큼 넓은 쪽에 놓고, 둘 다 좁으면(메뉴처럼 큰 대상) 화면 아래쪽에 겹쳐 놓는다.
    const tipHeight = 250.0;
    final roomBelow = centered ? 0.0 : size.height - rect.bottom;
    final roomAbove = centered ? 0.0 : rect.top;
    final placeBelow = roomBelow >= tipHeight && roomBelow >= roomAbove;
    final placeAbove = !placeBelow && roomAbove >= tipHeight;

    final skipButton = TextButton(
      key: const Key('tutorial-skip'),
      onPressed: _skip,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black.withAlpha(110),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('건너뛰기', style: TextStyle(fontWeight: FontWeight.w600)),
    );

    final tip = _TipCard(
      key: ValueKey(_index),
      isDark: isDark,
      step: step,
      index: _index,
      total: widget.steps.length,
      isLast: _isLast,
      onNext: _next,
      onPrev: _index == 0 ? null : _prev,
      showArt: centered,
    );
    // 건너뛰기는 말풍선 왼쪽 아래에 붙어서 말풍선을 따라다닌다.
    final card = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isLast && step.skipAtTop) ...[
          skipButton,
          const SizedBox(height: 8),
        ],
        tip,
        if (!_isLast && !step.skipAtTop) ...[
          const SizedBox(height: 8),
          skipButton,
        ],
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _skip();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // 막: 대상 영역만 구멍을 낸다. 구멍은 단계가 바뀔 때 부드럽게 옮겨간다.
            Positioned.fill(
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: rect ?? Rect.zero),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (_, r, _) => CustomPaint(
                  painter: _ScrimPainter(
                    hole: centered || !_ready ? null : r,
                    color: Colors.black.withAlpha(isDark ? 190 : 165),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (_ready)
              if (centered)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: card,
                  ),
                )
              else
                Positioned(
                  left: 20,
                  right: 20,
                  top: placeBelow ? rect.bottom + 14 : null,
                  bottom: placeBelow
                      ? null
                      : placeAbove
                      ? size.height - rect.top + 14
                      : 24,
                  child: card,
                ),
          ],
        ),
      ),
    );
  }
}

class _ScrimPainter extends CustomPainter {
  final Rect? hole;
  final Color color;
  _ScrimPainter({required this.hole, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final path = hole == null
        ? full
        : Path.combine(
            PathOperation.difference,
            full,
            Path()..addRRect(
              RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
            ),
          );
    canvas.drawPath(path, Paint()..color = color);
    if (hole != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(hole!, const Radius.circular(18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withAlpha(200),
      );
    }
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.hole != hole || old.color != color;
}

class _TipCard extends StatelessWidget {
  final bool isDark;
  final CoachStep step;
  final int index;
  final int total;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback? onPrev;
  final bool showArt;

  const _TipCard({
    super.key,
    required this.isDark,
    required this.step,
    required this.index,
    required this.total,
    required this.isLast,
    required this.onNext,
    required this.onPrev,
    required this.showArt,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showArt && step.art != null) ...[
            Center(child: step.art!(context)),
            const SizedBox(height: 16),
          ],
          Text(
            step.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: TextStyle(fontSize: 14.5, color: subColor, height: 1.55),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '${index + 1} / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
              const Spacer(),
              if (onPrev != null)
                TextButton(
                  key: const Key('tutorial-prev'),
                  onPressed: onPrev,
                  style: TextButton.styleFrom(foregroundColor: subColor),
                  child: const Text('이전'),
                ),
              const SizedBox(width: 6),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextButton(
                  key: const Key('tutorial-next'),
                  onPressed: onNext,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLast ? '시작하기' : '다음',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 마지막 단계(알림창에서 수정·지우기)에 쓰는 그림. 알림창은 앱 화면 밖이라 따로 그린다.
class NotificationActionsArt extends StatelessWidget {
  const NotificationActionsArt({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    Widget action(String label, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
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
