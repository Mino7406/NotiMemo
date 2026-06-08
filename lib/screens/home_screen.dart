import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../storage/memo_storage.dart';
import '../theme/app_theme.dart';
import 'faq_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode currentMode;
  final void Function(ThemeMode) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  List<MemoEntry> _memoList = [];
  bool _isPinning = false;
  bool _hasActiveNotification = false;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    NotificationService.requestPermission();
    NotificationService.listenForDismissal(() {
      if (mounted) setState(() => _hasActiveNotification = false);
    });
    _checkUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncNotificationState();
  }

  Future<void> _checkUpdate() async {
    final newVersion = await UpdateService.checkForUpdate();
    if (newVersion != null && mounted) _showUpdateDialog(newVersion);
  }

  void _showUpdateDialog(String version) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
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
                    child: const Icon(Icons.system_update_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '업데이트 알림',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'v$version 버전이 출시되었습니다.\n지금 업데이트하시겠어요?',
                style: TextStyle(fontSize: 14, color: subColor, height: 1.6),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: subColor),
                    child: const Text('나중에'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      launchUrl(
                        Uri.parse(UpdateService.releasesUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.gradStart,
                    ),
                    child: const Text(
                      '업데이트',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncNotificationState() async {
    final isActive = await MemoStorage.isNotificationActive();
    if (mounted) setState(() => _hasActiveNotification = isActive);
  }

  Future<void> _load() async {
    final current = await MemoStorage.getCurrent();
    final list = await MemoStorage.getList();
    final isActive = await MemoStorage.isNotificationActive();
    setState(() {
      if (current != null) {
        _controller.text = current;
      }
      _memoList = list;
      _hasActiveNotification = isActive;
    });
  }

  Future<void> _cancelNotification() async {
    if (!_hasActiveNotification) return;
    await NotificationService.cancel();
    await MemoStorage.clearCurrent();
    await MemoStorage.setNotificationActive(false);
    setState(() => _hasActiveNotification = false);
    _toast('알림이 해제되었습니다.');
  }

  Future<void> _createNotification() async {
    final memo = _controller.text.trim();
    if (memo.isEmpty) {
      _toast('메모를 입력해주세요.', isError: true);
      return;
    }
    final permStatus = await NotificationService.checkPermission();
    if (permStatus == 'permanentlyDenied') {
      _toast('알림 권한이 차단되었습니다. 설정에서 허용해주세요.', isError: true);
      return;
    }
    if (permStatus != 'granted') {
      final granted = await NotificationService.requestPermission();
      if (!granted) {
        _toast('알림 권한이 필요합니다.', isError: true);
        return;
      }
    }
    setState(() => _isPinning = true);
    try {
      await NotificationService.show(memo);
      await MemoStorage.setCurrent(memo);
      await MemoStorage.setNotificationActive(true);
      final updated = [
        MemoEntry(memo: memo, time: DateTime.now().millisecondsSinceEpoch),
        ..._memoList,
      ];
      await MemoStorage.saveList(updated);
      setState(() {
        _memoList = updated;
        _hasActiveNotification = true;
      });
      _toast('알림이 고정되었습니다!');
    } catch (e) {
      _toast('오류: $e', isError: true);
    } finally {
      setState(() => _isPinning = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(msg, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(
        memoList: _memoList,
        onDelete: (i) async {
          final updated = List<MemoEntry>.from(_memoList)..removeAt(i);
          await MemoStorage.saveList(updated);
          setState(() => _memoList = updated);
        },
        onClearAll: () async {
          await MemoStorage.saveList([]);
          setState(() => _memoList = []);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
          children: [
            _TopBar(
              subColor: subColor,
              textColor: textColor,
              currentMode: widget.currentMode,
              onThemeChanged: widget.onThemeChanged,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroText(textColor: textColor, subColor: subColor),
                    const SizedBox(height: 24),
                    _InputCard(
                      controller: _controller,
                      isDark: isDark,
                      textColor: textColor,
                      subColor: subColor,
                      onClear: () {
                        _controller.clear();
                        MemoStorage.setCurrent('');
                      },
                    ),
                    const SizedBox(height: 14),
                    _PinButton(
                      isPinning: _isPinning,
                      onTap: _createNotification,
                    ),
                    const SizedBox(height: 10),
                    _CancelButton(
                      isDark: isDark,
                      isActive: _hasActiveNotification,
                      onTap: _cancelNotification,
                    ),
                    const SizedBox(height: 10),
                    _HistoryButton(
                      count: _memoList.length,
                      isDark: isDark,
                      subColor: subColor,
                      onTap: _showHistory,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final Color textColor;
  final Color subColor;
  final ThemeMode currentMode;
  final void Function(ThemeMode) onThemeChanged;

  const _TopBar({
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
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: subColor, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FaqScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: subColor, size: 22),
            onPressed: () => Navigator.push(
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

class _HeroText extends StatelessWidget {
  final Color textColor;
  final Color subColor;
  const _HeroText({required this.textColor, required this.subColor});

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

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final Color textColor;
  final Color subColor;
  final VoidCallback onClear;

  const _InputCard({
    required this.controller,
    required this.isDark,
    required this.textColor,
    required this.subColor,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
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
              ],
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
                controller: controller,
                maxLines: 6,
                minLines: 6,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (v) => MemoStorage.setCurrent(v),
                style: TextStyle(fontSize: 16, height: 1.6, color: textColor),
                decoration: InputDecoration(
                  hintText: '기억해야 할 것을 입력하세요...',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF3D3F52) : const Color(0xFFD1D5DB),
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
            child: _ClearButton(onTap: onClear, subColor: subColor),
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color subColor;
  const _ClearButton({required this.onTap, required this.subColor});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
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

class _PinButton extends StatefulWidget {
  final bool isPinning;
  final VoidCallback onTap;
  const _PinButton({required this.isPinning, required this.onTap});

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
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

class _HistoryButton extends StatefulWidget {
  final int count;
  final bool isDark;
  final Color subColor;
  final VoidCallback onTap;

  const _HistoryButton({
    required this.count,
    required this.isDark,
    required this.subColor,
    required this.onTap,
  });

  @override
  State<_HistoryButton> createState() => _HistoryButtonState();
}

class _HistoryButtonState extends State<_HistoryButton> {
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

class _CancelButton extends StatefulWidget {
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;
  const _CancelButton({
    required this.isDark,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_CancelButton> createState() => _CancelButtonState();
}

class _CancelButtonState extends State<_CancelButton> {
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
                '알림 지우기',
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

// ── History Bottom Sheet ───────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  final List<MemoEntry> memoList;
  final Future<void> Function(int) onDelete;
  final Future<void> Function() onClearAll;

  const _HistorySheet({
    required this.memoList,
    required this.onDelete,
    required this.onClearAll,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late List<MemoEntry> _list;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.memoList);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '알림 내역',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_list.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_list.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (_list.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await widget.onClearAll();
                      setState(() => _list.clear());
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    child: const Text(
                      '전체삭제',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // List or empty state
          if (_list.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 52,
                    color: subColor.withAlpha(80),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '저장된 메모가 없어요',
                    style: TextStyle(color: subColor, fontSize: 15),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                itemCount: _list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.elevatedDark
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _list[i].memo,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                                height: 1.45,
                              ),
                            ),
                            if (_list[i].time != 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                _formatEntryTime(_list[i].time),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: subColor.withAlpha(160),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: subColor),
                        onPressed: () async {
                          await widget.onDelete(i);
                          setState(() => _list.removeAt(i));
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                            minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SizedBox(height: bottomPad + 20),
        ],
      ),
    );
  }
}

String _formatEntryTime(int ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final h = dt.hour;
  final ampm = h < 12 ? '오전' : '오후';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final m = dt.minute.toString().padLeft(2, '0');
  final timeStr = '$ampm $h12:$m';
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return timeStr;
  }
  if (dt.year == now.year) {
    return '${dt.month}/${dt.day} $timeStr';
  }
  return '${dt.year}/${dt.month}/${dt.day} $timeStr';
}
