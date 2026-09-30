import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/update_service.dart';
import '../models/memo_entry.dart';
import '../storage/memo_storage.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_toast.dart';
import '../widgets/history_sheet.dart';
import '../widgets/home_widgets.dart';

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
    if (newVersion != null && mounted) showUpdateDialog(context, newVersion);
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

  void _toast(String msg, {bool isError = false}) =>
      showAppToast(context, msg, isError: isError);

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
    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toast(permError, isError: true);
      return;
    }
    setState(() => _isPinning = true);
    try {
      await NotificationService.show(memo);
      await MemoStorage.setCurrent(memo);
      await MemoStorage.setNotificationActive(true);
      final updated = [
        MemoEntry.create(memo),
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

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistorySheet(
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
        onRestore: _restoreMemo,
      ),
    );
  }

  Future<void> _restoreMemo(MemoEntry entry) async {
    final confirmed = await showRestoreConfirmDialog(context, entry.memo);
    if (!confirmed || !mounted) return;

    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toast(permError, isError: true);
      return;
    }
    try {
      await NotificationService.show(entry.memo);
      await MemoStorage.setCurrent(entry.memo);
      await MemoStorage.setNotificationActive(true);
      _controller.text = entry.memo;
      setState(() => _hasActiveNotification = true);
      _toast('알림이 다시 생성되었습니다!');
    } catch (e) {
      _toast('오류: $e', isError: true);
    }
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
            TopBar(
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
                    HeroText(textColor: textColor, subColor: subColor),
                    const SizedBox(height: 24),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _hasActiveNotification
                          ? Column(
                              children: [
                                ActiveBanner(isDark: isDark),
                                const SizedBox(height: 10),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                    InputCard(
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
                    PinButton(
                      isPinning: _isPinning,
                      onTap: _createNotification,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CancelButton(
                            isDark: isDark,
                            isActive: _hasActiveNotification,
                            onTap: _cancelNotification,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: HistoryButton(
                            count: _memoList.length,
                            isDark: isDark,
                            subColor: subColor,
                            onTap: _showHistory,
                          ),
                        ),
                      ],
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
