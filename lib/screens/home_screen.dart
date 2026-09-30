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
  Set<String> _pinnedIds = {};

  bool get _hasActiveNotification => _pinnedIds.isNotEmpty;

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
    NotificationService.listenForDismissal(_syncNotificationState);
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
    final ids = await MemoStorage.getPinnedIds();
    if (mounted) setState(() => _pinnedIds = ids);
  }

  Future<void> _load() async {
    final current = await MemoStorage.getCurrent();
    final list = await MemoStorage.getList();
    final pinned = await MemoStorage.getPinnedIds();
    setState(() {
      if (current != null) {
        _controller.text = current;
      }
      _memoList = list;
      _pinnedIds = pinned;
    });
  }

  void _toast(String msg, {bool isError = false}) =>
      showAppToast(context, msg, isError: isError);

  Future<void> _cancelNotification() async {
    if (!_hasActiveNotification) return;
    await NotificationService.cancel();
    setState(() => _pinnedIds = {});
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
      final entry = MemoEntry.create(memo);
      await NotificationService.show(entry);
      final updated = [entry, ..._memoList];
      await MemoStorage.saveList(updated);
      _controller.clear();
      await MemoStorage.clearCurrent();
      setState(() {
        _memoList = updated;
        _pinnedIds = {..._pinnedIds, entry.id};
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
      // 옛 포맷에서 온 기록은 time이 0이라, 다시 고정하는 시각으로 표시한다.
      final now = DateTime.now().millisecondsSinceEpoch;
      await NotificationService.show(
          MemoEntry(id: entry.id, memo: entry.memo, time: now));
      setState(() => _pinnedIds = {..._pinnedIds, entry.id});
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
                                ActiveBanner(isDark: isDark, count: _pinnedIds.length),
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
                            label: _pinnedIds.length > 1 ? '모두 지우기' : '알림 지우기',
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
