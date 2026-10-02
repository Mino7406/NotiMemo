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
import '../utils/reminder_time.dart';
import '../utils/time_format.dart';
import '../widgets/analysis_sheet.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_drawer.dart';
import '../widgets/coach_mark.dart';
import 'settings_screen.dart';
import '../widgets/app_toast.dart';
import '../widgets/history_sheet.dart';
import '../widgets/home_widgets.dart';
import '../widgets/notice_button.dart';
import '../widgets/photo_source_sheet.dart';
import '../widgets/scheduled_sheet.dart';
import '../widgets/schedule_sheet.dart';

// 메인 화면: 메모 입력, 알림 고정, 예약, AI 정리 등 대부분의 기능이 여기서 시작된다
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

// 화면 상태. 입력창 글, 저장된 내역·고정·예약 목록, 진행 중인 작업 표시 등을 들고 있다
class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  // 알림 내역(저장된 메모 전체)
  List<MemoEntry> _memoList = [];
  // 고정/인식/분석이 진행 중일 때 버튼 중복 클릭을 막으려는 표시
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
  // 지금 알림창에 떠 있는 메모의 id
  Set<String> _pinnedIds = {};
  // 예약해 둔 메모 목록
  List<ScheduledNote> _scheduled = [];

  /// 예약 목록에서 입력창으로 불러온 메모의 id. 다시 고정/예약하면 같은 메모가 갱신된다.
  String? _editingId;

  bool get _hasActiveNotification => _pinnedIds.isNotEmpty;

  // 화면이 처음 열릴 때 아래에서 올라오며 나타나는 애니메이션
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
    // 알림 권한 창이 사용 방법과 겹치지 않도록 사용 방법이 끝난 뒤에 요청한다.
    _load()
        .then((_) => _maybeShowTutorial())
        .then((_) async {
          final target = await NotificationService.launchTarget();
          if (target != null && mounted) _openTarget(target);
        })
        .then((_) => NotificationService.requestPermission())
        .then((_) => _checkNotificationPermission());
    NotificationService.restorePinned();
    NotificationService.listenForChanges(
      _syncNotificationState,
      onOpenTarget: _openTarget,
    );
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
    if (state == AppLifecycleState.resumed) {
      NotificationService.restorePinned();
      _checkNotificationPermission();
      _syncNotificationState();
    }
  }

  // 앱을 켤 때 새 버전이 있는지 확인하고 있으면 안내 창을 띄운다
  Future<void> _checkUpdate() async {
    final newVersion = await UpdateService.checkForUpdate();
    if (newVersion != null && mounted) showUpdateDialog(context, newVersion);
  }

  // 알림이 바뀌었을 때(지움, 수정, 예약 발동 등) 저장된 값을 다시 읽어서 화면에 맞춘다
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
    await _startTutorial(firstRun: true);
  }

  /// 홈 화면 위에 코치마크로 사용 방법을 안내한다. ✨·🕒는 글이 있어야 보이므로 샘플 글을 잠시 넣고,
  /// 끝나면 원래 입력으로 되돌린다. [firstRun]이면 끝난 뒤(건너뛰기·뒤로 가기 포함) 본 것으로 기록한다.
  Future<void> _startTutorial({bool firstRun = false}) async {
    final saved = _controller.text;
    FocusScope.of(context).unfocus();
    _controller.text = '금요일 오후 3시 치과 예약 꼭 가기';
    Future<void> closeMenu() async =>
        _scaffoldKey.currentState?.closeEndDrawer();
    await showCoachMarks(
      context,
      steps: [
        const CoachStep(
          target: Key('input-card'),
          title: '여기에 메모를 적어요',
          body: '떠오르는 일을 적어 두세요.\n사진 속 글자를 불러와 적을 수도 있어요.',
        ),
        const CoachStep(
          target: Key('pin-button'),
          title: '알림창에 고정해요',
          body: '[알림 고정하기]를 누르면 메모가 알림창에 남아서\n언제든 확인할 수 있어요.',
        ),
        const CoachStep(
          target: Key('card-analyze'),
          title: 'AI가 자동으로 정리해줘요',
          body: '✨를 누르면 분류·우선순위·메모 요약과\n일정 시각까지 찾아 줘요.',
        ),
        const CoachStep(
          target: Key('card-schedule'),
          title: '원하는 시각에 알려 줘요',
          body: '🕒로 시각을 정하면 그때 알림창에 고정돼요.\nAI가 생각 후 예약 추천도 해줘요.',
        ),
        CoachStep(
          target: const Key('menu-drawer'),
          title: '더 많은 기능은 ☰ 메뉴에 있어요',
          body: '사진으로 메모 가져오기, 예약 목록, 알림 내역,\n설정을 이 메뉴에서 열 수 있어요.',
          onEnter: () async => _scaffoldKey.currentState?.openEndDrawer(),
          onExit: closeMenu,
          skipAtTop: true,
        ),
        CoachStep(
          title: '알림창에서 바로 고치고 지워요',
          body: '앱을 열지 않아도 알림에서 [수정]하거나\n[지우기]로 정리할 수 있어요.',
          art: (_) => const NotificationActionsArt(),
        ),
      ],
      onClose: () async {
        await closeMenu();
        if (mounted) _controller.text = saved;
        if (firstRun) await TutorialStorage.setSeen();
      },
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

  // 앱을 켤 때 임시 저장된 글과 내역·고정·예약 목록을 불러온다
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

  // 예약 목록에서 고른 메모를 입력창으로 가져와 다시 고칠 수 있게 한다
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

  // AI 정리 결과를 비운다
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

  // 안내 말풍선을 끈다
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

  // 요약으로 바꿨을 때 되돌리기 버튼이 있는 토스트를 띄운다
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

  /// 지금 떠 있는 "알림 권한이 꺼져 있어요 [설정]" 토스트(권한이 켜지면 닫는다).
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _permToast;

  /// 알림 권한이 꺼져 있으면 [설정] 버튼이 달린 토스트를 계속 띄워 둔다. 켜져 있으면 닫는다.
  /// 앱을 열 때와 설정에서 돌아왔을 때 부른다.
  Future<void> _checkNotificationPermission() async {
    final status = await NotificationService.checkPermission();
    if (!mounted) return;
    if (status == 'granted') {
      _permToast?.close();
      _permToast = null;
    } else if (_permToast == null) {
      _toastPermission('알림 권한이 꺼져 있어요.');
    }
  }

  /// 권한 안내 토스트. 닫을 때까지 남고, [설정]을 누르면 권한 요청 창(막혔으면 앱 설정)을 다시 연다.
  void _toastPermission(String msg) {
    final toast = showAppToast(
      context,
      msg,
      isError: true,
      actionLabel: '설정',
      duration: const Duration(days: 1),
      onAction: () async {
        await NotificationService.requestOrOpenSettings();
        await _checkNotificationPermission();
      },
    );
    _permToast = toast;
    toast.closed.then((_) {
      if (identical(_permToast, toast)) _permToast = null;
    });
  }

  // 토스트를 간단히 띄우는 줄임 함수
  void _toast(String msg, {bool isError = false}) =>
      showAppToast(context, msg, isError: isError);

  // 사진에서 읽은 글을 입력창에 넣고 ✨ 안내를 보여준다
  void _fillFromPhoto(String text) {
    _setMemoText(text);
    _toast('사진으로부터 글자를 불러왔어요.');
    _showAiHint(); // ✨를 눌러 AI로 정리해 보라고 가리킨다
  }

  /// 사진에서 글자를 읽어 입력창에 불러온다. 고치고 고정/예약하는 건 사용자 몫이다.
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
      // 사진 글자는 이어 붙이지 않고 그 자리를 대신한다. 이미 쓴 글이 있으면 먼저 묻는다.
      if (_controller.text.trim().isEmpty) {
        _fillFromPhoto(text);
      } else {
        showAppToast(
          context,
          '기존 메모를 지우고 불러오시겠습니까?',
          isError: true,
          actionLabel: '적용',
          duration: const Duration(seconds: 7),
          onAction: () {
            if (mounted) _fillFromPhoto(text);
          },
        );
      }
    } catch (e) {
      if (mounted) _toast('글자를 읽지 못했어요: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isReadingPhoto = false);
    }
  }

  // 고정된 알림을 전부 내린다
  Future<void> _cancelNotification() async {
    if (!_hasActiveNotification) return;
    await NotificationService.cancel();
    setState(() => _pinnedIds = {});
    _toast('알림이 해제되었습니다.');
  }

  // 입력한 메모를 알림창에 고정한다. 권한 확인 → 알림 게시 → 내역 저장 순서로 한다
  Future<void> _createNotification() async {
    final memo = _controller.text.trim();
    if (memo.isEmpty) {
      _askForMemo();
      return;
    }
    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toastPermission(permError);
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
      if (!wasEditing) NotificationService.vibrate();
    } catch (e) {
      _toast('오류: $e', isError: true);
    } finally {
      setState(() => _isPinning = false);
    }
  }

  // 시각을 골라서 예약 고정한다. 시각이 지난 값이면 다시 고르게 한다
  Future<void> _scheduleNotification({DateTime? initial}) async {
    final memo = _controller.text.trim();
    if (memo.isEmpty) {
      _askForMemo();
      return;
    }
    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toastPermission(permError);
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
      NotificationService.vibrate();
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

  /// 위젯에서 항목을 눌러 들어왔을 때 해당 목록(예약 목록/알림 내역)을 연다.
  void _openTarget(String target) {
    if (!mounted) return;
    if (target == 'scheduled') {
      _openScheduled();
    } else if (target == 'history') {
      _showHistory();
    }
  }

  // 예약 목록을 열고, 고른 항목이 있으면 예약을 취소하고 입력창으로 불러온다
  Future<void> _openScheduled() async {
    final picked = await showScheduledSheet(context);
    await _syncNotificationState();
    if (picked == null || !mounted) return;
    await NotificationService.cancelSchedule(picked.id);
    _loadForEdit(picked.id, picked.memo);
    await _syncNotificationState();
    _toast('예약을 취소하고 입력창으로 불러왔어요.');
  }

  // 알림 내역 시트를 연다. 삭제·전체삭제·다시 고정은 시트에서 넘어온 콜백으로 처리한다
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

  // 내역에서 고른 메모를 다시 고정하거나 예약한다
  Future<void> _restoreMemo(MemoEntry entry) async {
    final choice = await showRestoreConfirmDialog(context, entry.memo);
    if (choice == null || !mounted) return;

    final permError = await NotificationService.ensurePermission();
    if (permError != null) {
      _toastPermission(permError);
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
      NotificationService.vibrate();
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
      NotificationService.vibrate();
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
      key: _scaffoldKey,
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
        onTutorial: _startTutorial,
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
                          key: const Key('input-card'),
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
                          key: const Key('pin-button'),
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
