import 'dart:async';
import 'package:flutter/material.dart';
import '../models/memo_analysis.dart';
import '../services/ai_classifier.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../services/update_service.dart';
import '../models/memo_entry.dart';
import '../models/scheduled_note.dart';
import '../storage/ai_storage.dart';
import '../storage/memo_storage.dart';
import '../storage/tutorial_storage.dart';
import '../theme/app_theme.dart';
import '../utils/analysis_labels.dart';
import '../utils/rule_classifier.dart';
import '../utils/due_parser.dart';
import '../utils/ocr_text.dart';
import '../utils/reminder_time.dart';
import '../utils/time_format.dart';
import '../widgets/analysis_sheet.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_drawer.dart';
import 'tutorial_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/history_sheet.dart';
import '../widgets/home_widgets.dart';
import '../widgets/notice_button.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/scheduled_sheet.dart';
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
  bool _isAnalyzing = false;

  /// 사진에서 글자를 가져온 직후, ✨ 버튼을 가리키는 안내를 보여주는 중인지.
  bool _aiHint = false;
  Timer? _aiHintTimer;

  /// 지금 떠 있는 "요약으로 바꿨어요 [되돌리기]" 토스트와, 그 토스트가 유효한 메모 글(요약).
  /// 메모가 그 글에서 달라지면(지움·수정·고정·예약) 되돌릴 대상이 사라진 것이므로 토스트를 닫는다.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoToast;
  String? _undoExpectedText;

  /// 분석을 적용하지 않은 메모에도 기본 분석으로 분류를 채울지(설정의 자동 분류).
  bool _classify = true;

  /// 사용자가 "적용"한 자동 정리 결과와 그 대상 메모(공백 정리한 글). 메모가 바뀌면 무효.
  final _inputFocus = FocusNode();
  MemoAnalysis? _analysis;
  String? _analyzedMemo;
  Set<String> _pinnedIds = {};
  List<ScheduledNote> _scheduled = [];

  /// 예약 목록에서 입력창으로 불러온 메모의 id. 다시 고정/예약하면 같은 메모가 갱신된다.
  String? _editingId;

  bool get _hasActiveNotification => _pinnedIds.isNotEmpty;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _fadeAnim = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slideAnim = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_dismissStaleUndo);
    _load().then((_) => _maybeShowTutorial());
    NotificationService.requestPermission();
    NotificationService.listenForChanges(_syncNotificationState);
    _checkUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
  }

  @override
  void dispose() {
    _controller.removeListener(_dismissStaleUndo);
    _aiHintTimer?.cancel();
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _inputFocus.dispose();
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

  /// 처음 설치한 사람에게만 튜토리얼을 보여준다. 이미 쓰던 흔적(히스토리·고정)이 있으면 조용히 본 것으로 친다.
  Future<void> _maybeShowTutorial() async {
    if (await TutorialStorage.getSeen() || !mounted) return;
    if (_memoList.isNotEmpty ||
        _pinnedIds.isNotEmpty ||
        _scheduled.isNotEmpty) {
      await TutorialStorage.setSeen();
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TutorialScreen(firstRun: true)),
    );
  }

  /// 분류가 없는 옛 내역을 기본 분석으로 채워 저장한다([_classify]가 켜져 있을 때만).
  Future<List<MemoEntry>> _backfilled(List<MemoEntry> list) async {
    if (!_classify) return list;
    final result = backfillClassification(list, DateTime.now());
    if (result.changed) await MemoStorage.saveList(result.list);
    return result.list;
  }

  /// 설정에서 돌아왔을 때 자동 분류 설정을 다시 읽고, 켜졌다면 빈 내역을 채운다.
  Future<void> _refreshClassify() async {
    _classify = await AiStorage.classificationEnabled();
    final list = await _backfilled(await MemoStorage.getList());
    if (mounted) setState(() => _memoList = list);
  }

  Future<void> _load() async {
    final current = await MemoStorage.getCurrent();
    _classify = await AiStorage.classificationEnabled();
    final list = await _backfilled(await MemoStorage.getList());
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
    final MemoEntry base;
    if (id == null) {
      base = MemoEntry.create(memo);
    } else {
      final existing = _memoList.where((e) => e.id == id).firstOrNull;
      base =
          existing?.copyWith(memo: memo) ??
          MemoEntry(
            id: id,
            memo: memo,
            time: DateTime.now().millisecondsSinceEpoch,
          );
    }
    return _withAnalysis(base, memo);
  }

  /// 적용해 둔 자동 정리 결과를 [entry]에 담는다(메모가 그대로일 때만).
  MemoEntry _withAnalysis(MemoEntry entry, String memo) {
    final a = _analysis;
    if (a == null || _analyzedMemo != memo) {
      // ✨를 적용하지 않았어도 분류가 비어 있지 않게 기본 분석으로 채운다.
      return _classify ? withRuleClassification(entry, DateTime.now()) : entry;
    }
    return entry.copyWith(
      category: a.category,
      priority: a.priority,
      // 메모 자체가 요약으로 바뀐 경우에는 같은 내용을 한 번 더 저장하지 않는다.
      summary: a.summary.isEmpty || a.summary.trim() == memo ? null : a.summary,
    );
  }

  void _clearAnalysis() {
    _analysis = null;
    _analyzedMemo = null;
    _hideAiHint(); // 지우거나 고정·예약해서 새로 시작하면 안내도 끝낸다(setState 없이 값만)
  }

  /// ✨ 안내를 켠다. 사용자가 누르지 않아도 [seconds]초 뒤에 저절로 꺼진다.
  void _showAiHint({int seconds = 12}) {
    _aiHintTimer?.cancel();
    setState(() => _aiHint = true);
    _aiHintTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) setState(() => _aiHint = false);
    });
  }

  void _hideAiHint() {
    _aiHintTimer?.cancel();
    _aiHint = false;
  }

  /// ✨ 자동 정리: 동의 확인 → 분석(AI, 안 되면 기본) → 결과 시트 → 적용.
  Future<void> _analyze() async {
    if (_isAnalyzing) return;
    // 안내 말풍선은 ✨를 눌렀다면(또는 말풍선을 눌렀다면) 역할을 다한 것이다.
    if (_aiHint) setState(_hideAiHint);
    final memo = _controller.text.trim();
    if (memo.isEmpty) {
      _askForMemo();
      return;
    }
    // AI를 켰지만 자동 분류를 끈 경우: 분류·요약 없이 메모의 예약 시각만 찾는다(서버 전송 없음).
    if (await AiStorage.getConsent() == true &&
        !await AiStorage.getAutoClassify()) {
      await _suggestTimeOnly(memo);
      return;
    }
    if (await AiStorage.getConsent() == null) {
      if (!mounted) return;
      final answer = await showAiConsentDialog(context);
      if (answer == null || !mounted) return; // 닫으면 아무것도 정하지 않는다.
      await AiStorage.setConsent(answer);
    }
    setState(() => _isAnalyzing = true);
    final MemoAnalysis analysis;
    try {
      analysis = await AiClassifier().analyze(memo);
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
    if (!mounted) return;
    if (_controller.text.trim() != memo) {
      _toast('정리하는 동안 메모가 바뀌어 적용하지 않았어요.', isError: true);
      return;
    }
    final leadMinutes = await AiStorage.getLeadMinutes();
    if (!mounted) return;
    final decision = await showAnalysisSheet(
      context,
      analysis,
      leadMinutes: leadMinutes,
    );
    if (decision == null || !mounted) return;
    // 요약이 있으면 새 메모를 그 요약으로 바꾼다. 원문은 "되돌리기"로 되살릴 수 있다.
    final summary = analysis.summary.trim();
    final replaced = summary.isNotEmpty && summary != memo;
    if (replaced) _setMemoText(summary);
    setState(() {
      _analysis = analysis;
      _analyzedMemo = replaced ? summary : memo;
    });
    if (decision == AnalysisDecision.applyAndSchedule) {
      final due = analysis.due;
      await _scheduleNotification(
        initial: due == null
            ? null
            : suggestReminder(
                due,
                DateTime.now(),
                leadMinutes: leadMinutes,
              ).remindAt,
      );
      // 예약하지 않고 닫아서 메모가 그대로 남아 있다면 되돌릴 수 있게 알린다.
      if (replaced && mounted && _controller.text.trim() == summary) {
        _toastSummaryApplied(memo, summary, analysis);
      }
    } else if (replaced) {
      _toastSummaryApplied(memo, summary, analysis);
    } else {
      _toast('자동 정리를 적용했어요.');
    }
  }

  /// 입력창의 글을 바꾸고 임시 저장도 갱신한다(커서는 끝으로).
  void _setMemoText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    MemoStorage.setCurrent(text);
  }

  void _toastSummaryApplied(String original, String summary, MemoAnalysis a) {
    final toast = showAppToast(
      context,
      '새 메모를 요약으로 바꿨어요.',
      actionLabel: '되돌리기',
      duration: const Duration(seconds: 6),
      onAction: () => _undoSummary(original, summary, a),
    );
    _undoToast = toast;
    _undoExpectedText = summary;
    // 저절로 닫히거나 다른 토스트로 바뀌면 추적을 끝낸다(남의 토스트를 닫지 않도록).
    toast.closed.then((_) {
      if (identical(_undoToast, toast)) {
        _undoToast = null;
        _undoExpectedText = null;
      }
    });
  }

  /// 메모가 "되돌리기" 대상(요약)에서 달라졌으면 그 토스트를 닫는다. 메모를 다 지웠거나,
  /// 고쳤거나, 고정·예약해서 비워진 경우다. 글이 그대로면(커서만 움직인 경우 등) 아무것도 안 한다.
  void _dismissStaleUndo() {
    final toast = _undoToast;
    final expected = _undoExpectedText;
    if (toast == null || expected == null) return;
    if (_controller.text.trim() == expected) return;
    _undoToast = null;
    _undoExpectedText = null;
    toast.close();
  }

  /// 요약으로 바꾼 메모를 원래 글로 되돌린다. 그 사이 요약을 고쳤다면 사용자의 수정을
  /// 덮어쓰지 않도록 되돌리지 않는다.
  void _undoSummary(String original, String summary, MemoAnalysis a) {
    if (!mounted) return;
    if (_controller.text.trim() != summary) {
      _toast('요약을 고쳐서 되돌릴 수 없어요.', isError: true);
      return;
    }
    _setMemoText(original);
    setState(() {
      _analysis = a;
      _analyzedMemo = original; // 분류·우선순위는 원문에도 그대로 적용된다
    });
  }

  /// 자동 분류를 끈 ✨: 메모에서 시각만 찾아 여유 시간을 뺀 값으로 예약 시트를 연다.
  Future<void> _suggestTimeOnly(String memo) async {
    final due = parseDue(memo, DateTime.now());
    if (due == null) {
      _toast('메모에서 예약 시각을 찾지 못했어요.', isError: true);
      return;
    }
    final leadMinutes = await AiStorage.getLeadMinutes();
    if (!mounted) return;
    await _scheduleNotification(
      initial: suggestReminder(
        due,
        DateTime.now(),
        leadMinutes: leadMinutes,
      ).remindAt,
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
      _toast('사진으로부터 글자를 불러왔어요.');
      _showAiHint(); // ✨를 눌러 AI로 정리해 보라고 가리킨다
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
      _askForMemo();
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
        _clearAnalysis();
      });
      await _syncNotificationState();
      _toast(wasEditing ? '알림이 수정되었습니다!' : '알림이 고정되었습니다!');
    } catch (e) {
      _toast('오류: $e', isError: true);
    } finally {
      setState(() => _isPinning = false);
    }
  }

  Future<void> _scheduleNotification({DateTime? initial}) async {
    final memo = _controller.text.trim();
    if (memo.isEmpty) {
      _askForMemo();
      return;
    }
    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toast(permError, isError: true);
      return;
    }
    if (!mounted) return;
    final at = await showScheduleSheet(context, initial: initial);
    if (at == null || !mounted) return;
    if (!at.isAfter(DateTime.now())) {
      _toast('지금보다 이후 시각을 골라주세요.', isError: true);
      return;
    }
    await _ensureExactAlarm();
    try {
      final entry = _entryFor(
        memo,
      ).copyWith(scheduledAt: at.millisecondsSinceEpoch);
      await NotificationService.schedule(entry, at);
      final updated = await _saveEntry(entry);
      _controller.clear();
      await MemoStorage.clearCurrent();
      setState(() {
        _memoList = updated;
        _editingId = null;
        _clearAnalysis();
      });
      await _syncNotificationState();
      _toast('${formatEntryTime(at.millisecondsSinceEpoch)}에 고정되도록 예약했어요.');
    } catch (e) {
      _toast('오류: $e', isError: true);
    }
  }

  /// 메모가 비어 있을 때: 안내하고 입력창에 포커스를 줘서 바로 입력할 수 있게 한다.
  /// 메뉴가 닫히는 동안에는 포커스가 돌아가 버려서 조금 기다렸다가 준다.
  void _askForMemo() {
    _toast('메모를 입력해주세요.', isError: true);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  /// 빨간 ✕: 지울 글을 보여주며 한 번 더 묻고, 확인하면 새 메모와 분석 결과를 비운다.
  Future<void> _confirmClearMemo() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final ok = await showClearMemoDialog(context, text);
    if (!ok || !mounted) return;
    _controller.clear();
    MemoStorage.setCurrent('');
    setState(() {
      _editingId = null;
      _clearAnalysis();
    });
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
          NoticeButton(
            label: '나중에',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          NoticeButton(
            label: '설정 열기',
            color: AppColors.gradStart,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (open == true) await NotificationService.requestExactAlarm();
  }

  Future<void> _openScheduled() async {
    final picked = await showScheduledSheet(context);
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
    final choice = await showRestoreConfirmDialog(context, entry.memo);
    if (choice == null || !mounted) return;

    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toast(permError, isError: true);
      return;
    }
    if (choice == RestoreChoice.schedule) {
      await _scheduleExisting(entry);
      return;
    }
    try {
      // 옛 포맷에서 온 기록은 time이 0이라, 다시 고정하는 시각으로 표시한다.
      final now = DateTime.now().millisecondsSinceEpoch;
      await NotificationService.show(
        MemoEntry(id: entry.id, memo: entry.memo, time: now),
      );
      setState(() => _pinnedIds = {..._pinnedIds, entry.id});
      _toast('알림이 다시 생성되었습니다!');
    } catch (e) {
      _toast('오류: $e', isError: true);
    }
  }

  /// 알림 내역의 메모를 시각을 골라 예약 고정한다(분류·우선순위는 그대로 유지).
  Future<void> _scheduleExisting(MemoEntry entry) async {
    final at = await showScheduleSheet(context);
    if (at == null || !mounted) return;
    if (!at.isAfter(DateTime.now())) {
      _toast('지금보다 이후 시각을 골라주세요.', isError: true);
      return;
    }
    await _ensureExactAlarm();
    try {
      final scheduled = entry.copyWith(scheduledAt: at.millisecondsSinceEpoch);
      await NotificationService.schedule(scheduled, at);
      final updated = await _saveEntry(scheduled);
      setState(() => _memoList = updated);
      await _syncNotificationState();
      _toast('${formatEntryTime(at.millisecondsSinceEpoch)}에 고정되도록 예약했어요.');
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
      endDrawer: AppMenuDrawer(
        scheduledCount: _scheduled.length,
        historyCount: _memoList.length,
        isBusy: _isAnalyzing || _isReadingPhoto,
        onAnalyze: _analyze,
        onPhoto: _readPhoto,
        onSchedule: _scheduleNotification,
        onScheduledList: _openScheduled,
        onHistory: _showHistory,
        onSettings: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                currentMode: widget.currentMode,
                onThemeChanged: widget.onThemeChanged,
              ),
            ),
          );
          await _refreshClassify();
        },
        onTutorial: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TutorialScreen()),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                TopBar(subColor: subColor, textColor: textColor),
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
                                    ActiveBanner(
                                      isDark: isDark,
                                      count: _pinnedIds.length,
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        InputCard(
                          controller: _controller,
                          focusNode: _inputFocus,
                          onAnalyze: _analyze,
                          isAnalyzing: _isAnalyzing,
                          showAiHint: _aiHint,
                          onSchedule: _scheduleNotification,
                          isDark: isDark,
                          textColor: textColor,
                          subColor: subColor,
                          onClear: _confirmClearMemo,
                        ),
                        if (_isAnalyzing || _isReadingPhoto)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: const LinearProgressIndicator(
                                key: Key('busy-indicator'),
                                minHeight: 3,
                                color: AppColors.gradStart,
                              ),
                            ),
                          ),
                        // 적용해 둔 자동 정리 결과(메모를 고치면 사라진다)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (_, value, _) {
                            final a = _analysis;
                            if (a == null ||
                                _analyzedMemo != value.text.trim()) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: AppliedAnalysisChips(
                                category: a.category,
                                priorityLabel: priorityLabel(a.priority),
                                isAi: a.source == AnalysisSource.ai,
                                isDark: isDark,
                                subColor: subColor,
                                onRemove: () => setState(_clearAnalysis),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        PinButton(
                          isPinning: _isPinning,
                          onTap: _createNotification,
                        ),
                        const SizedBox(height: 10),
                        CancelButton(
                          isDark: isDark,
                          isActive: _hasActiveNotification,
                          label: _pinnedIds.length > 1 ? '모두 지우기' : '알림 지우기',
                          onTap: _cancelNotification,
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
