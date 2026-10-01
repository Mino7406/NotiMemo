import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/update_service.dart';
import '../models/memo_entry.dart';
import '../models/scheduled_note.dart';
import '../storage/memo_storage.dart';
import '../utils/ocr_text.dart';
import '../utils/time_format.dart';
import 'scheduled_screen.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_toast.dart';
import '../widgets/history_sheet.dart';
import '../widgets/home_widgets.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/schedule_sheet.dart';

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
  bool _isReadingPhoto = false;
  Set<String> _pinnedIds = {};
  List<ScheduledNote> _scheduled = [];

  /// 예약 목록에서 입력창으로 불러온 메모의 id. 다시 고정/예약하면 같은 메모가 갱신된다.
  String? _editingId;

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
    NotificationService.listenForChanges(_syncNotificationState);
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
    final scheduled = await MemoStorage.getScheduled();
    final list = await MemoStorage.getList();
    if (mounted) {
      setState(() {
        _pinnedIds = ids;
        _scheduled = scheduled;
        _memoList = list;
      });
    }
  }

  Future<void> _load() async {
    final current = await MemoStorage.getCurrent();
    final list = await MemoStorage.getList();
    final pinned = await MemoStorage.getPinnedIds();
    final scheduled = await MemoStorage.getScheduled();
    setState(() {
      if (current != null) {
        _controller.text = current;
      }
      _memoList = list;
      _pinnedIds = pinned;
      _scheduled = scheduled;
    });
  }

  void _loadForEdit(String id, String memo) {
    _controller.text = memo;
    _controller.selection = TextSelection.collapsed(offset: memo.length);
    setState(() => _editingId = id);
  }

  /// 지금 입력한 메모를 고정/예약할 항목으로 만든다. 수정 중이면 같은 id를 유지한다.
  MemoEntry _entryFor(String memo) {
    final id = _editingId;
    if (id == null) return MemoEntry.create(memo);
    final existing = _memoList.where((e) => e.id == id).firstOrNull;
    return existing?.copyWith(memo: memo) ??
        MemoEntry(
          id: id,
          memo: memo,
          time: DateTime.now().millisecondsSinceEpoch,
        );
  }

  /// [entry]를 히스토리 맨 앞에 두고(이미 있으면 그 자리를 갱신) 저장한다.
  Future<List<MemoEntry>> _saveEntry(MemoEntry entry) async {
    final idx = _memoList.indexWhere((e) => e.id == entry.id);
    final updated = idx < 0
        ? [entry, ..._memoList]
        : (List<MemoEntry>.from(_memoList)..[idx] = entry);
    await MemoStorage.saveList(updated);
    return updated;
  }

  void _toast(String msg, {bool isError = false}) =>
      showAppToast(context, msg, isError: isError);

  /// 사진에서 글자를 읽어 입력창에 이어 붙인다. 고치고 고정/예약하는 건 사용자 몫이다.
  Future<void> _readPhoto() async {
    if (_isReadingPhoto) return;
    final source = await showPhotoSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _isReadingPhoto = true);
    try {
      final text = await OcrService.readFromPhoto(source);
      if (!mounted || text == null) return; // null = 사용자가 사진 선택을 취소함
      if (text.isEmpty) {
        _toast('글자를 찾지 못했어요.', isError: true);
        return;
      }
      final merged = appendRecognizedText(_controller.text, text);
      _controller.value = TextEditingValue(
        text: merged,
        selection: TextSelection.collapsed(offset: merged.length),
      );
      MemoStorage.setCurrent(merged);
      _toast('글자를 불러왔어요. 고친 뒤 고정해보세요.');
    } catch (e) {
      if (mounted) _toast('글자를 읽지 못했어요: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isReadingPhoto = false);
    }
  }

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
      final wasEditing = _editingId != null;
      final entry = _entryFor(memo).copyWith(clearScheduledAt: true);
      await NotificationService.show(entry);
      // 예약돼 있던 메모를 고쳐서 바로 고정하면 남은 예약은 취소한다.
      await NotificationService.cancelSchedule(entry.id);
      final updated = await _saveEntry(entry);
      _controller.clear();
      await MemoStorage.clearCurrent();
      setState(() {
        _memoList = updated;
        _pinnedIds = {..._pinnedIds, entry.id};
        _editingId = null;
      });
      await _syncNotificationState();
      _toast(wasEditing ? '알림이 수정되었습니다!' : '알림이 고정되었습니다!');
    } catch (e) {
      _toast('오류: $e', isError: true);
    } finally {
      setState(() => _isPinning = false);
    }
  }

  Future<void> _scheduleNotification() async {
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
    if (!mounted) return;
    final at = await showScheduleSheet(context);
    if (at == null || !mounted) return;
    if (!at.isAfter(DateTime.now())) {
      _toast('지금보다 이후 시각을 골라주세요.', isError: true);
      return;
    }
    await _ensureExactAlarm();
    try {
      final entry = _entryFor(memo).copyWith(
        scheduledAt: at.millisecondsSinceEpoch,
      );
      await NotificationService.schedule(entry, at);
      final updated = await _saveEntry(entry);
      _controller.clear();
      await MemoStorage.clearCurrent();
      setState(() {
        _memoList = updated;
        _editingId = null;
      });
      await _syncNotificationState();
      _toast('${formatEntryTime(at.millisecondsSinceEpoch)}에 고정되도록 예약했어요.');
    } catch (e) {
      _toast('오류: $e', isError: true);
    }
  }

  /// 정확한 알람 권한이 없으면 안내하고 설정 화면을 열어준다. 거절해도 예약은 계속한다(정확도가 낮아짐).
  Future<void> _ensureExactAlarm() async {
    if (await NotificationService.canScheduleExact() || !mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정확한 알람 허용'),
        content: const Text(
          '정해진 시각에 정확히 고정하려면 "알람 및 리마인더" 권한이 필요해요. '
          '허용하지 않으면 몇 분 늦게 고정될 수 있어요.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('나중에')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('설정 열기')),
        ],
      ),
    );
    if (open == true) await NotificationService.requestExactAlarm();
  }

  Future<void> _openScheduled() async {
    final picked = await Navigator.push<ScheduledNote>(
      context,
      MaterialPageRoute(builder: (_) => const ScheduledScreen()),
    );
    await _syncNotificationState();
    if (picked == null || !mounted) return;
    await NotificationService.cancelSchedule(picked.id);
    _loadForEdit(picked.id, picked.memo);
    await _syncNotificationState();
    _toast('예약을 취소하고 입력창으로 불러왔어요.');
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
                        setState(() => _editingId = null);
                      },
                      onPhoto: _readPhoto,
                      isReadingPhoto: _isReadingPhoto,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: PinButton(
                            isPinning: _isPinning,
                            onTap: _createNotification,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SquareIconButton(
                          icon: Icons.schedule_rounded,
                          tooltip: '예약 고정',
                          isDark: isDark,
                          onTap: _scheduleNotification,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    HistoryButton(
                      label: '예약 목록',
                      icon: Icons.event_note_rounded,
                      count: _scheduled.length,
                      isDark: isDark,
                      subColor: subColor,
                      onTap: _openScheduled,
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
