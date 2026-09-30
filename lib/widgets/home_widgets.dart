import 'package:flutter/material.dart';
import '../screens/faq_screen.dart';
import '../screens/settings_screen.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';

class TopBar extends StatelessWidget {
  final Color textColor;
  final Color subColor;
  final ThemeMode currentMode;
  final void Function(ThemeMode) onThemeChanged;

  const TopBar({
    super.key,
    required this.textColor,
    required this.subColor,
    required this.currentMode,
    required this.onThemeChanged,
  });

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
            child: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 17),
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
            icon: Icons.help_outline_rounded,
            color: subColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            ),
          ),
          AnimatedIconButton(
            icon: Icons.settings_outlined,
            color: subColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  currentMode: currentMode,
                  onThemeChanged: onThemeChanged,
                ),
              ),
            ),
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

  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(widget.icon, color: widget.color, size: 22),
        ),
      ),
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
            child: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 14),
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

  const InputCard({
    super.key,
    required this.controller,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.onClear,
  });

  @override
  State<InputCard> createState() => _InputCardState();
}

class _InputCardState extends State<InputCard> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
                      shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                      child: const Icon(Icons.push_pin_rounded, color: Colors.white, size: 15),
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
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                maxLines: 6,
                minLines: 6,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (v) => MemoStorage.setCurrent(v),
                style: TextStyle(fontSize: 16, height: 1.6, color: widget.textColor),
                decoration: InputDecoration(
                  hintText: '기억해야 할 것을 입력하세요...',
                  hintStyle: TextStyle(
                    color: widget.isDark ? const Color(0xFF3D3F52) : const Color(0xFFD1D5DB),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          Positioned(
            top: 4,
            right: 4,
            child: ClearButton(onTap: widget.onClear, subColor: widget.subColor),
          ),
        ],
      ),
    );
  }
}

class ClearButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color subColor;
  const ClearButton({super.key, required this.onTap, required this.subColor});

  @override
  State<ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<ClearButton> {
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(Icons.close_rounded, size: 18, color: widget.subColor),
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

  const HistoryButton({
    super.key,
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
                  : (widget.isDark ? AppColors.borderDark : AppColors.borderLight),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 20, color: widget.subColor),
              const SizedBox(width: 8),
              Text(
                '알림 내역',
                style: TextStyle(
                  color: widget.subColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.count > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              Icon(Icons.notifications_off_rounded, size: 20, color: contentColor),
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
