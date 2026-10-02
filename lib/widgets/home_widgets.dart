import 'package:flutter/material.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  final Color textColor;
  final Color subColor;

  const TopBar({super.key, required this.textColor, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
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
          Text(
            '알림메모',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          AnimatedIconButton(
            key: const Key('menu-button'),
            icon: Icons.menu_rounded,
            color: textColor,
            size: 28,
            outlined: true,
            onTap: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
    );
  }
}

class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// 아이콘 크기.
  final double size;

  /// true면 윤곽선 있는 둥근 네모 버튼(터치 영역이 눈에 보인다). 최소 터치 영역 48dp.
  final bool outlined;

  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
    this.outlined = false,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.8 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.outlined ? _outlined(context) : _plain(),
      ),
    );
  }

  Widget _plain() => Padding(
    padding: const EdgeInsets.all(12),
    child: Icon(widget.icon, color: widget.color, size: widget.size),
  );

  Widget _outlined(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.5,
        ),
      ),
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}

class ActiveBanner extends StatelessWidget {
  final bool isDark;
  final int count;
  const ActiveBanner({super.key, required this.isDark, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gradStart.withAlpha(isDark ? 28 : 18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gradStart.withAlpha(isDark ? 70 : 55),
        ),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: const Icon(
              Icons.push_pin_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count > 1 ? '알림 $count개가 고정되어 있어요' : '알림이 현재 고정되어 있어요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.gradStart.withAlpha(isDark ? 210 : 190),
            ),
          ),
          const Spacer(),
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppColors.gradStart,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class HeroText extends StatelessWidget {
  final Color textColor;
  final Color subColor;
  const HeroText({super.key, required this.textColor, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '지금 기억해야 할 것은 \n무엇인가요?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '메모를 알림창에 고정해 언제든지 확인하세요.',
          style: TextStyle(fontSize: 14, color: subColor, height: 1.5),
        ),
      ],
    );
  }
}

class InputCard extends StatefulWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final VoidCallback onClear;

  /// 밖에서 입력창에 포커스를 줄 때 쓴다. 없으면 카드가 자체 노드를 만든다.
  final FocusNode? focusNode;

  /// 메모가 입력되면 ✕ 아래에 나타나는 빠른 실행 버튼들. null이면 보여주지 않는다.
  final VoidCallback? onAnalyze;
  final bool isAnalyzing;
  final VoidCallback? onSchedule;

  /// true면 ✨ 버튼을 가리키는 반투명 깜빡이는 안내 말풍선을 보여주고 ✨도 같은 박자로 맥박친다.
  /// 사진에서 글자를 가져온 직후처럼 "다음엔 AI 정리를 눌러 보라"고 알려줄 때 쓴다.
  final bool showAiHint;

  const InputCard({
    super.key,
    required this.controller,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.onClear,
    this.focusNode,
    this.onAnalyze,
    this.isAnalyzing = false,
    this.onSchedule,
    this.showAiHint = false,
  });

  @override
  State<InputCard> createState() => _InputCardState();
}

class _InputCardState extends State<InputCard>
    with SingleTickerProviderStateMixin {
  late final _focusNode = widget.focusNode ?? FocusNode();
  bool _focused = false;

  /// 안내 말풍선·✨의 깜빡임/맥박 박자(0→1→0 반복).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(InputCard old) {
    super.didUpdateWidget(old);
    if (old.showAiHint != widget.showAiHint) _syncPulse();
  }

  void _syncPulse() {
    if (widget.showAiHint) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focused
              ? AppColors.gradStart.withAlpha(180)
              : (widget.isDark ? AppColors.borderDark : AppColors.borderLight),
          width: _focused ? 1.5 : 1.0,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.gradStart.withAlpha(50),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ]
            : (widget.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withAlpha(18),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: const Icon(
                        Icons.push_pin_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '새 메모',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gradStart,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                // 사진 글자나 긴 글이 들어와 높이가 바뀔 때 카드가 갑자기 튀지 않게 부드럽게 늘어난다.
                duration: _inputGrowDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  // 최소 6줄에서 시작해 글 길이에 맞춰 늘어난다(제한 없음). 넘치는 건 화면 스크롤로 본다.
                  maxLines: null,
                  minLines: _inputMinLines,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (v) => MemoStorage.setCurrent(v),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: widget.textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: '기억해야 할 것을 입력하세요...',
                    hintStyle: TextStyle(
                      color: widget.isDark
                          ? const Color(0xFF3D3F52)
                          : const Color(0xFFD1D5DB),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(
                      16,
                      10,
                      _cardChipSize + _cardChipInset * 2,
                      0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          // ✨(두 번째 버튼)의 가운데 높이, 그 왼쪽에 놓는다. 메모가 비면 숨는다.
          if (widget.showAiHint && widget.onAnalyze != null)
            Positioned(
              top: _cardChipInset + _chipTop(1) + _cardChipSize / 2 - 17,
              right: _cardChipInset + _cardChipSize + 4,
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (_, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : AiHintBubble(
                        key: const Key('ai-hint'),
                        animation: _pulse,
                      ),
              ),
            ),
          Positioned(
            // 위쪽 모서리에서 고정 간격으로 쌓는다.
            top: _cardChipInset,
            right: _cardChipInset,
            width: _cardChipSize,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, value, _) {
                final has = value.text.isNotEmpty;
                final specs = <_ChipSpec>[
                  _ChipSpec(
                    key: const Key('clear-memo'),
                    icon: Icons.close_rounded,
                    color: AppColors.danger,
                    tooltip: '새 메모 지우기',
                    onTap: widget.onClear,
                  ),
                  if (widget.onAnalyze != null)
                    _ChipSpec(
                      key: const Key('card-analyze'),
                      icon: Icons.auto_awesome_outlined,
                      color: AppColors.gradStart,
                      tooltip: 'AI 자동 정리',
                      loading: widget.isAnalyzing,
                      pulse: widget.showAiHint ? _pulse : null,
                      onTap: widget.isAnalyzing ? () {} : widget.onAnalyze!,
                    ),
                  if (widget.onSchedule != null)
                    _ChipSpec(
                      key: const Key('card-schedule'),
                      icon: Icons.schedule_rounded,
                      color: AppColors.gradStart,
                      tooltip: '예약 생성',
                      onTap: widget.onSchedule!,
                    ),
                ];
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < specs.length; i++) ...[
                      if (i > 0)
                        SizedBox(
                          // ✕(삭제) 바로 아래만 넓게 벌려서 ✨·🕒를 누르려다 ✕를 잘못 누르지 않게 한다.
                          height: i == 1 ? _cardChipSeparation : _cardChipGap,
                        ),
                      _PopChip(
                        key: specs[i].key,
                        visible: has,
                        order: i,
                        count: specs.length,
                        icon: specs[i].icon,
                        color: specs[i].color,
                        tooltip: specs[i].tooltip,
                        loading: specs[i].loading,
                        pulse: specs[i].pulse,
                        onTap: specs[i].onTap,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 입력창 오른쪽 버튼의 크기와 카드 안쪽 여백.
/// 새 메모 입력창의 최소 줄 수(글이 이보다 길어지면 그만큼 늘어난다).
const int _inputMinLines = 6;

/// 입력창이 글 길이에 맞춰 늘어나고 줄어드는 시간. 과하지 않게 짧게 둔다.
const Duration _inputGrowDuration = Duration(milliseconds: 220);

const double _cardChipSize = 34;
const double _cardChipInset = 12;

/// ✨·🕒가 나타날 때 미끄러져 들어오는 시작 위치(버튼 폭의 배수, 오른쪽). 카드 오른쪽 가장자리를
/// 벗어나 처음에는 보이지 않다가 안쪽으로 들어오면서 나타난다.
const Offset _slideInFrom = Offset(1.6, 0);

/// 같은 성격의 버튼(✨·🕒) 사이 세로 간격.
const double _cardChipGap = 8;

/// 삭제(✕)와 그 아래 기능 버튼(✨·🕒) 사이 간격. 삭제 버튼을 따로 떼어 두려고 더 넓게 둔다.
const double _cardChipSeparation = 28;

/// i번째 버튼의 위쪽 끝이 첫 버튼(✕)의 위쪽 끝에서 떨어진 거리.
double _chipTop(int i) => i == 0
    ? 0
    : (_cardChipSize + _cardChipSeparation) +
          (i - 1) * (_cardChipSize + _cardChipGap);

/// [_PopChip]에 넘기는 버튼 정보.
class _ChipSpec {
  final Key key;
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool loading;
  final VoidCallback onTap;

  /// 주목시킬 때 버튼을 살짝 키웠다 줄이는 박자. 없으면 가만히 있는다.
  final Animation<double>? pulse;

  const _ChipSpec({
    required this.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
    this.pulse,
  });
}

/// 입력창 오른쪽의 윤곽선 버튼. 메모가 비어 있으면 숨어 있다가 입력되면 나타난다.
///
/// 나타나는 순서: 0번(✕)이 **제자리에서 먼저** 커지며 나타나고, 뒤이어 1번·2번이
/// **카드 오른쪽 바깥에서 옆으로 미끄러져 들어와** 각자 자리에 멈춘다(시차를 두고). ✕와 ✨·🕒는
/// 떨어져 있는 별도 그룹이라 ✕ 자리에서 내려오지 않는다. 숨을 때는 모두 한꺼번에 빠르게 사라진다.
class _PopChip extends StatelessWidget {
  final bool visible;

  /// 위에서부터의 순서(0 = ✕).
  final int order;

  /// 전체 버튼 수.
  final int count;

  final IconData icon;
  final Color color;
  final String tooltip;
  final bool loading;
  final VoidCallback onTap;
  final Animation<double>? pulse;

  const _PopChip({
    super.key,
    required this.visible,
    required this.order,
    required this.count,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
    this.pulse,
  });

  /// 나타나는 전체 시간(ms). 첫 버튼이 먼저 끝나고 나머지가 차례로 이어진다.
  static const showMs = 780;
  static const hideMs = 180;

  @override
  Widget build(BuildContext context) {
    final total = Duration(milliseconds: visible ? showMs : hideMs);
    // 순서별 시작·끝 시점(전체 시간 대비). 0번은 곧바로, 1번·2번은 뒤이어 시작한다.
    final begin = const [0.0, 0.24, 0.42][order.clamp(0, 2)];
    final end = const [0.34, 0.74, 1.0][order.clamp(0, 2)];
    final fadeEnd = begin + (end - begin) * 0.6;

    final slideCurve = visible
        ? Interval(begin, end, curve: Curves.easeOutCubic)
        : Curves.easeIn;
    final scaleCurve = visible
        ? Interval(
            begin,
            end,
            curve: order == 0 ? Curves.easeOutBack : Curves.easeOutCubic,
          )
        : Curves.easeIn;
    final fadeCurve = visible
        ? Interval(begin, fadeEnd, curve: Curves.easeOut)
        : Curves.easeIn;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        // 0번(✕)은 제자리에서 커지며 나타나고, 나머지는 카드 오른쪽 바깥(카드 가장자리에서
        // 잘려 보이지 않는 곳)에서 옆으로 미끄러져 들어온다.
        offset: visible || order == 0 ? Offset.zero : _slideInFrom,
        duration: total,
        curve: slideCurve,
        child: AnimatedScale(
          scale: visible || order != 0 ? 1 : 0.5,
          duration: total,
          curve: scaleCurve,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: total,
            curve: fadeCurve,
            child: Tooltip(
              message: tooltip,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: _pulsing(
                  Container(
                    width: _cardChipSize,
                    height: _cardChipSize,
                    decoration: BoxDecoration(
                      color: color.withAlpha(18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color, width: 1.4),
                    ),
                    child: loading
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(icon, size: 19, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// [pulse]가 있으면 버튼을 박자에 맞춰 살짝 키웠다 줄인다.
  Widget _pulsing(Widget child) {
    final p = pulse;
    if (p == null) return child;
    return ScaleTransition(
      scale: Tween<double>(
        begin: 1.0,
        end: 1.16,
      ).animate(CurvedAnimation(parent: p, curve: Curves.easeInOut)),
      child: child,
    );
  }
}

/// ✨ 버튼을 가리키는 반투명 안내 말풍선. [animation]에 맞춰 흐릿했다 또렷해지길 반복한다.
///
/// **누를 수 없는 안내**다. AI 정리는 ✨ 버튼으로만 시작한다. 말풍선은 글자 위에 떠 있으므로 터치를
/// 가로채지 않게 해서(IgnorePointer), 누르면 그 아래의 입력창이 그대로 반응한다.
class AiHintBubble extends StatelessWidget {
  final Animation<double> animation;

  const AiHintBubble({super.key, required this.animation});

  static const text = 'AI가 자동으로 분석해줘요!';

  /// 가장 흐릴 때와 가장 또렷할 때의 투명도.
  static const minOpacity = 0.3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(animation.value);
        return Opacity(
          key: const Key('ai-hint-opacity'),
          opacity: minOpacity + (1 - minOpacity) * t,
          child: child,
        );
      },
      child: IgnorePointer(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.gradStart.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gradStart, width: 1.2),
              ),
              child: const Text(
                text,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gradStart,
                ),
              ),
            ),
            // ✨ 버튼 쪽(오른쪽)을 가리키는 삼각형
            const Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: AppColors.gradStart,
            ),
          ],
        ),
      ),
    );
  }
}

class PinButton extends StatefulWidget {
  final bool isPinning;
  final VoidCallback onTap;
  const PinButton({super.key, required this.isPinning, required this.onTap});

  @override
  State<PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<PinButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: AppColors.gradStart.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.gradStart.withAlpha(90),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: widget.isPinning
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.push_pin_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '알림 고정하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class HistoryButton extends StatefulWidget {
  final int count;
  final bool isDark;
  final Color subColor;
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const HistoryButton({
    super.key,
    this.label = '알림 내역',
    this.icon = Icons.history_rounded,
    required this.count,
    required this.isDark,
    required this.subColor,
    required this.onTap,
  });

  @override
  State<HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<HistoryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.gradStart.withAlpha(widget.isDark ? 30 : 20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pressed
                  ? AppColors.gradStart.withAlpha(widget.isDark ? 100 : 80)
                  : (widget.isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 20, color: widget.subColor),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.subColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.elevatedDark
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gradStart,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CancelButton extends StatefulWidget {
  final bool isDark;
  final bool isActive;
  final String label;
  final VoidCallback onTap;
  const CancelButton({
    super.key,
    required this.isDark,
    required this.isActive,
    this.label = '알림 지우기',
    required this.onTap,
  });

  @override
  State<CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<CancelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isActive;
    final contentColor = active
        ? AppColors.danger.withAlpha(widget.isDark ? 200 : 180)
        : (widget.isDark ? const Color(0xFF4B4C60) : const Color(0xFFCBCDD8));
    final borderColor = active
        ? AppColors.danger.withAlpha(widget.isDark ? 100 : 80)
        : (widget.isDark ? AppColors.borderDark : AppColors.borderLight);

    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.danger.withAlpha(widget.isDark ? 30 : 20)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_rounded,
                size: 20,
                color: contentColor,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: contentColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고정 버튼 옆에 두는 정사각형 보조 버튼 (예약 등).
class SquareIconButton extends StatefulWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<SquareIconButton> createState() => _SquareIconButtonState();
}

class _SquareIconButtonState extends State<SquareIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.gradStart.withAlpha(widget.isDark ? 30 : 20)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
                width: 1.5,
              ),
            ),
            child: Icon(widget.icon, size: 24, color: AppColors.gradStart),
          ),
        ),
      ),
    );
  }
}

/// 자동 정리 결과가 이 메모에 적용돼 있음을 입력창 아래에 보여준다. ✕로 적용을 취소한다.
class AppliedAnalysisChips extends StatelessWidget {
  final String category;
  final String priorityLabel;
  final bool isAi;
  final bool isDark;
  final Color subColor;
  final VoidCallback onRemove;

  const AppliedAnalysisChips({
    super.key,
    required this.category,
    required this.priorityLabel,
    required this.isAi,
    required this.isDark,
    required this.subColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.gradStart.withAlpha(isDark ? 24 : 14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gradStart.withAlpha(isDark ? 60 : 45),
        ),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$category · 우선순위 $priorityLabel · ${isAi ? 'AI' : '기본'} 분석 적용됨',
              key: const Key('applied-analysis'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.gradStart.withAlpha(isDark ? 220 : 200),
              ),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, size: 16, color: subColor),
            ),
          ),
        ],
      ),
    );
  }
}
