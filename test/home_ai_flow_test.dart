import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/screens/home_screen.dart';
import 'package:notimemo/storage/ai_storage.dart';
import 'package:notimemo/storage/settings_storage.dart';
import 'package:notimemo/theme/app_theme.dart';
import 'package:notimemo/services/ocr_service.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:notimemo/utils/rule_classifier.dart';
import 'package:notimemo/storage/tutorial_storage.dart';
import 'package:notimemo/widgets/app_toast.dart';
import 'package:notimemo/widgets/home_widgets.dart'
    show AppliedAnalysisChips, CancelButton, InputCard;
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 화면 전체 흐름 테스트. 네이티브 채널은 가짜로 대체하고, AI 서버 통신은
/// 테스트 환경이 막아(HTTP 400) 항상 "서버 오류 → 기본 분석" 경로로 간다.
const _notiChannel = MethodChannel('com.example.notimemo/notification');
const _permChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

// 시각 계산이 현재 시각에 따라 달라지지 않게 "꼭"(급함 표현)으로 우선순위를 high로 고정한다.
const memo = '꼭 내일 오후 3시 수학 숙제 제출';

final shown = <MethodCall>[];

void mockChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  shown.clear();
  messenger.setMockMethodCallHandler(_notiChannel, (call) async {
    shown.add(call);
    return call.method == 'canScheduleExact' ? true : null;
  });
  messenger.setMockMethodCallHandler(_permChannel, (call) async {
    switch (call.method) {
      case 'checkPermissionStatus':
        return 1; // granted
      case 'requestPermissions':
        return {17: 1}; // 알림 권한 허용
    }
    return null;
  });
}

/// 홈 화면 테스트. 홈이 열릴 때 업데이트 확인이 만드는 8초 타이머가 테스트 종료 때
/// 남아 있으면 프레임워크가 오류로 보므로, 끝에서 시간을 흘려보내 정리한다.
void homeTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    // 업데이트 확인(8초)과 사진 인식 안내(12초)의 타이머가 남지 않게 정리한다.
    await tester.pump(const Duration(seconds: 13));
  });
}

Future<void> openHome(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(currentMode: ThemeMode.light, onThemeChanged: (_) {}),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

Future<void> typeMemo(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

/// 오른쪽 메뉴를 연다.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('menu-button')));
  await tester.pumpAndSettle();
}

/// ✨를 누르고 분석(비동기 입출력 포함)이 끝날 때까지 기다린다.
Future<void> tapAnalyze(WidgetTester tester) async {
  await openMenu(tester);
  await tester.tap(find.byKey(const Key('analyze-button')));
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_consent': true,
      'tutorial_seen': true,
    });
    mockChannels();
  });

  homeTest('오른쪽 메뉴에 ✨ 버튼이 있다', (tester) async {
    await openHome(tester);
    await openMenu(tester);
    expect(find.byKey(const Key('analyze-button')), findsOneWidget);
  });

  homeTest('메모가 비었으면 안내만 하고 시트를 열지 않는다', (tester) async {
    await openHome(tester);
    await tapAnalyze(tester);
    expect(find.text('메모를 입력해주세요.'), findsOneWidget);
    expect(find.text('자동 정리'), findsNothing);
  });

  homeTest('동의한 상태: 결과 시트가 열리고 기본 분석 + 서버 오류 이유가 보인다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    expect(find.text('자동 정리'), findsOneWidget);
    expect(find.text('기본 분석'), findsOneWidget); // 테스트 환경은 서버 통신이 막힘
    expect(find.byKey(const Key('fallback-message')), findsOneWidget);
    expect(find.byKey(const Key('category-chip')), findsOneWidget);
    expect(find.text('학교'), findsOneWidget);
    expect(find.text('우선순위 높음'), findsOneWidget);
    expect(find.text('예약 시각 제안'), findsOneWidget);
    expect(find.text('적용하고 예약 시각 확인'), findsOneWidget);
  });

  homeTest('적용하면 입력창 아래에 적용 표시가 뜨고, 메모를 고치면 사라진다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tap(find.text('적용만 하기'));
    await tester.pumpAndSettle();
    expect(find.text('학교 · 우선순위 높음 · 기본 분석 적용됨'), findsOneWidget);

    await typeMemo(tester, '$memo 그리고 영어도');
    expect(find.byKey(const Key('applied-analysis')), findsNothing);
  });

  homeTest('적용 표시의 ✕를 누르면 적용이 취소된다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tap(find.text('적용만 하기'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppliedHost),
        matching: find.byIcon(Icons.close_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('applied-analysis')), findsNothing);
  });

  homeTest('시트를 닫으면(적용 안 함) 표시가 없다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('applied-analysis')), findsNothing);
  });

  group('진동', () {
    int vibrations() => shown.where((c) => c.method == 'vibrate').length;

    homeTest('고정하면 진동한다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, memo);
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      expect(vibrations(), 1);
    });

    homeTest('설정에서 끄면 진동하지 않는다', (tester) async {
      await SettingsStorage.setVibration(false);
      await openHome(tester);
      await typeMemo(tester, memo);
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      expect(shown.where((c) => c.method == 'show'), hasLength(1));
      expect(vibrations(), 0);
    });
  });

  homeTest('적용한 뒤 고정하면 카테고리·우선순위가 히스토리에 저장된다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tap(find.text('적용만 하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('알림 고정하기'));
    await tester.pumpAndSettle();

    expect(shown.where((c) => c.method == 'show'), hasLength(1));
    final list = await MemoStorage.getList();
    expect(list, hasLength(1));
    expect(list.single.memo, memo);
    expect(list.single.category, '학교');
    expect(list.single.priority, MemoPriority.high);
    // 고정하면 입력창과 적용 표시가 비워진다.
    expect(find.byKey(const Key('applied-analysis')), findsNothing);
  });

  homeTest('✨ 적용 없이 고정하면 기본 분석으로 분류가 채워진다(요약은 비움)', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tester.tap(find.text('알림 고정하기'));
    await tester.pumpAndSettle();
    final entry = (await MemoStorage.getList()).single;
    expect(entry.category, '학교');
    expect(entry.priority, MemoPriority.high); // "꼭" = 급함 표현
    expect(entry.summary, isNull);
  });

  homeTest('적용한 뒤 메모를 고치고 고정하면 옛 분석 결과를 붙이지 않는다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tap(find.text('적용만 하기'));
    await tester.pumpAndSettle();

    await typeMemo(tester, '완전히 다른 메모');
    await tester.tap(find.text('알림 고정하기'));
    await tester.pumpAndSettle();

    final entry = (await MemoStorage.getList()).single;
    expect(entry.memo, '완전히 다른 메모');
    // 옛 분석(학교 · 높음)이 아니라 새 메모의 기본 분석 결과여야 한다.
    expect(entry.category, '기타');
    expect(entry.priority, MemoPriority.normal);
  });

  homeTest('적용하고 예약 시각 확인: 예약 시트가 열린다', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tapAnalyze(tester);
    await tester.tap(find.text('적용하고 예약 시각 확인'));
    await tester.pumpAndSettle();
    expect(find.text('언제 고정할까요?'), findsOneWidget);
    // 분석 결과도 함께 적용돼 있다.
    expect(find.byKey(const Key('applied-analysis')), findsOneWidget);
  });

  group('동의 흐름', () {
    homeTest('처음 누르면 동의 창: 동의하면 저장되고 분석이 이어진다', (tester) async {
      SharedPreferences.setMockInitialValues({'tutorial_seen': true});
      await openHome(tester);
      await typeMemo(tester, memo);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('외부 서버로 전송'), findsOneWidget);

      await tester.tap(find.text('동의하고 사용'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(await AiStorage.getConsent(), isTrue);
      expect(find.text('자동 정리'), findsOneWidget);
    });

    homeTest('AI 없이 사용을 고르면 거부가 저장되고 기본 분석 결과가 나온다', (tester) async {
      SharedPreferences.setMockInitialValues({'tutorial_seen': true});
      await openHome(tester);
      await typeMemo(tester, memo);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 없이 사용'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(await AiStorage.getConsent(), isFalse);
      expect(find.text('기본 분석'), findsOneWidget);
      expect(find.text('AI를 쓰지 않도록 설정돼 있어 기본 분석으로 정리했어요.'), findsOneWidget);
    });

    homeTest('동의 창을 닫으면 아무것도 저장되지 않고 분석도 하지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({'tutorial_seen': true});
      await openHome(tester);
      await typeMemo(tester, memo);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await AiStorage.getConsent(), isNull);
      expect(find.text('자동 정리'), findsNothing);
    });

    homeTest('거부한 뒤에는 다시 묻지 않고 기본 분석을 쓴다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_consent': false,
        'tutorial_seen': true,
      });
      await openHome(tester);
      await typeMemo(tester, memo);
      await tapAnalyze(tester);
      expect(find.textContaining('외부 서버로 전송'), findsNothing);
      expect(find.text('기본 분석'), findsOneWidget);
    });
  });

  group('알림 권한 안내', () {
    final requested = <String>[];
    void mockPermission(int status) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_permChannel, (call) async {
            requested.add(call.method);
            if (call.method == 'checkPermissionStatus') return status;
            if (call.method == 'requestPermissions') return {17: 1};
            return null;
          });
    }

    homeTest('권한이 꺼져 있으면 설정 버튼이 있는 토스트가 계속 떠 있다', (tester) async {
      requested.clear();
      mockPermission(0);
      await openHome(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('알림 권한이 꺼져 있어요'), findsOneWidget);
      expect(find.byKey(const Key('toast-action')), findsOneWidget);
      await tester.tap(find.byKey(const Key('toast-action')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(requested, contains('requestPermissions'));
      // 토스트의 하루짜리 타이머가 남지 않게 화면을 걷어낸다.
      await tester.pumpWidget(const SizedBox());
    });

    homeTest('권한이 켜져 있으면 토스트가 없다', (tester) async {
      mockPermission(1);
      await openHome(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining('알림 권한이 꺼져 있어요'), findsNothing);
    });
  });

  group('사용 방법(코치마크)', () {
    /// 단계 이동 뒤 구멍·말풍선이 자리잡도록 시간을 흘려 보낸다.
    Future<void> step(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    homeTest('처음 설치하면 코치마크가 뜨고, 끝까지 넘기면 본 것으로 저장된다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openHome(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('여기에 메모를 적어요'), findsOneWidget);
      expect(find.text('1 / 6'), findsOneWidget);
      for (final title in [
        '알림창에 고정해요',
        'AI가 자동으로 정리해줘요',
        '원하는 시각에 알려 줘요',
        '더 많은 기능은 ☰ 메뉴에 있어요',
        '알림창에서 바로 고치고 지워요',
      ]) {
        await step(tester);
        expect(find.text(title), findsOneWidget);
      }
      expect(find.text('시작하기'), findsOneWidget);
      await step(tester);
      expect(find.byKey(const Key('tutorial-next')), findsNothing);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('이전 버튼으로 앞 단계로 돌아갈 수 있고, 메뉴 단계에도 안내가 뜬다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openHome(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('tutorial-prev')), findsNothing);
      for (var i = 0; i < 4; i++) {
        await step(tester);
      }
      expect(find.text('더 많은 기능은 ☰ 메뉴에 있어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-prev')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('원하는 시각에 알려 줘요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pump(const Duration(milliseconds: 500));
    });

    homeTest('건너뛰기를 눌러도 본 것으로 저장되고 입력창은 원래대로 돌아온다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openHome(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('금요일 오후 3시 치과 예약 꼭 가기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('여기에 메모를 적어요'), findsNothing);
      expect(find.text('금요일 오후 3시 치과 예약 꼭 가기'), findsNothing);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('이미 쓰던 사용자(히스토리 있음)에게는 뜨지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await MemoStorage.saveList([MemoEntry(id: 'a', memo: '옛 메모', time: 1)]);
      await openHome(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('여기에 메모를 적어요'), findsNothing);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('메뉴의 사용 방법으로 다시 볼 수 있고, 쓰던 글은 보존된다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '내가 쓰던 글');
      await openMenu(tester);
      expect(find.text('사용 방법'), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu-tutorial')));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('여기에 메모를 적어요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('여기에 메모를 적어요'), findsNothing);
      expect(find.text('내가 쓰던 글'), findsOneWidget);
    });
  });

  homeTest('알림 내역 재생성: 예약해서 고정을 고르면 예약 시트가 열린다', (tester) async {
    await MemoStorage.saveList([MemoEntry(id: 'a', memo: '치과 예약', time: 1)]);
    await openHome(tester);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('menu-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-restore-a')));
    await tester.pumpAndSettle();
    expect(find.text('바로 고정'), findsOneWidget);
    await tester.tap(find.text('예약해서 고정'));
    await tester.pumpAndSettle();
    expect(find.text('언제 고정할까요?'), findsOneWidget);
  });

  homeTest('슬라이드 메뉴 닫기 버튼은 윤곽선이 있고 누르면 닫힌다', (tester) async {
    await openHome(tester);
    await openMenu(tester);
    final close = find.byKey(const Key('menu-close'));
    expect(close, findsOneWidget);
    final box = tester.widget<Container>(
      find.descendant(of: close, matching: find.byType(Container)),
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.width, greaterThan(0));
    expect(tester.getSize(close).width, greaterThanOrEqualTo(40));
    expect(find.byTooltip('닫기'), findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menu-close')), findsNothing);
  });

  homeTest('알림 내역 재생성: 바로 고정을 고르면 알림이 바로 뜬다', (tester) async {
    await MemoStorage.saveList([MemoEntry(id: 'a', memo: '치과 예약', time: 1)]);
    await openHome(tester);
    await openMenu(tester);
    await tester.tap(find.byKey(const Key('menu-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history-restore-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('바로 고정'));
    await tester.pumpAndSettle();
    expect(shown.any((c) => c.method == 'show'), isTrue);
    expect(find.text('언제 고정할까요?'), findsNothing);
  });

  group('분류 표시: 알림 내역과 예약 목록이 같다', () {
    Future<void> openList(WidgetTester tester, String key) async {
      await openMenu(tester);
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    homeTest('✨를 안 쓰고 바로 고정해도 알림 내역에 분류가 보인다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '수학 숙제 하기');
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();

      final saved = (await MemoStorage.getList()).single;
      expect(saved.category, '학교');
      expect(saved.priority, MemoPriority.normal);

      await openList(tester, 'menu-history');
      expect(find.text('학교 · 우선순위 보통'), findsOneWidget);
    });

    homeTest('분류 없이 저장돼 있던 옛 내역도 앱을 열면 채워져 보인다', (tester) async {
      await MemoStorage.saveList([
        const MemoEntry(id: 'a', memo: '우유 사기', time: 5),
        const MemoEntry(id: 'b', memo: '병원 가기', time: 6, category: '건강'),
      ]);
      await openHome(tester);
      final list = await MemoStorage.getList();
      expect(list.map((e) => e.category), ['쇼핑', '건강']); // 저장소에도 반영
      await openList(tester, 'menu-history');
      expect(find.text('쇼핑 · 우선순위 보통'), findsOneWidget);
      expect(find.text('건강 · 우선순위 보통'), findsOneWidget);
    });

    homeTest('예약 목록에도 같은 분류가 보인다', (tester) async {
      await MemoStorage.saveList([
        const MemoEntry(id: 's1', memo: '수학 숙제 제출', time: 5),
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'scheduled_notes',
        jsonEncode([
          {
            'id': 's1',
            'memo': '수학 숙제 제출',
            'at': DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
          },
        ]),
      );
      await openHome(tester);
      await openList(tester, 'menu-scheduled-list');
      expect(find.byKey(const Key('scheduled-label-s1')), findsOneWidget);
      expect(find.text('학교 · 우선순위 보통'), findsOneWidget);
    });

    homeTest('✨로 적용한 분류는 기본 분석이 덮어쓰지 않는다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, memo); // 급함 표현이라 우선순위 high
      await tapAnalyze(tester);
      await tester.tap(find.text('적용만 하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      final saved = (await MemoStorage.getList()).single;
      expect(saved.category, '학교');
      expect(saved.priority, MemoPriority.high);
    });

    homeTest('자동 분류를 끄면(AI 켠 상태) 채우지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'ai_consent': true,
        'tutorial_seen': true,
        'ai_auto_classify': false,
      });
      await MemoStorage.saveList([
        const MemoEntry(id: 'a', memo: '우유 사기', time: 5),
      ]);
      await openHome(tester);
      await typeMemo(tester, '수학 숙제 하기');
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      final list = await MemoStorage.getList();
      expect(list.map((e) => e.category), [null, null]); // 새 것도 옛 것도 그대로
      await openList(tester, 'menu-history');
      expect(find.textContaining('우선순위'), findsNothing);
    });
  });

  group('적용하면 새 메모가 요약으로 바뀐다', () {
    // 25자를 넘는 긴 메모 → 기본 분석이 첫 문장(30자 이내)으로 요약을 만든다.
    const long =
        '내일 학원 가기 전에 도서관에서 영어 단어장을 빌리고 사회 과제 자료도 찾아봐야 한다. 그리고 숙제 검사도 받아야 함';
    final summary = classifyByRules(long, DateTime.now()).summary;

    String memoText(WidgetTester tester) =>
        // 예약 시트가 열려 있으면 시각 입력 칸도 TextField라서, 홈 화면의 메모 칸(맨 처음)을 고른다.
        tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    Future<void> analyzeAndApplyOnly(WidgetTester tester, String text) async {
      await typeMemo(tester, text);
      await tapAnalyze(tester);
      // 예약 시각이 있으면 "적용만 하기", 없으면 "적용" 버튼 하나뿐이다.
      final applyOnly = find.text('적용만 하기');
      await tester.tap(
        applyOnly.evaluate().isNotEmpty ? applyOnly : find.text('적용'),
      );
      await tester.pumpAndSettle();
    }

    homeTest('요약이 만들어졌다(전제 확인)', (tester) async {
      expect(summary, isNotEmpty);
      expect(summary, isNot(long));
      expect(summary.length, lessThanOrEqualTo(30));
    });

    homeTest('결과 시트에 요약과 "메모가 바뀐다"는 안내가 보인다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, long);
      await tapAnalyze(tester);
      expect(find.byKey(const Key('summary-text')), findsOneWidget);
      expect(find.text(summary), findsOneWidget);
      expect(find.byKey(const Key('summary-replace-note')), findsOneWidget);
      expect(memoText(tester), long); // 적용하기 전에는 그대로
    });

    homeTest('적용하면 입력창의 메모가 요약으로 바뀌고 되돌리기가 뜬다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      expect(memoText(tester), summary);
      expect(find.text('새 메모를 요약으로 바꿨어요.'), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);
      // 분류 적용 표시는 바뀐 메모에도 계속 보인다.
      expect(find.byKey(const Key('applied-analysis')), findsOneWidget);
    });

    homeTest('되돌리기를 누르면 원래 글이 돌아오고 분류는 유지된다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(memoText(tester), long);
      expect(find.byKey(const Key('applied-analysis')), findsOneWidget);
      // 임시 저장도 원문으로 돌아간다(앱을 다시 열어도 요약이 아니라 원문).
      expect(await MemoStorage.getCurrent(), long);
    });

    homeTest('요약을 고친 뒤에는 되돌리기가 사용자의 수정을 덮어쓰지 않는다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await typeMemo(tester, '$summary 내가 고침');
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(memoText(tester), '$summary 내가 고침');
      expect(find.text('요약을 고쳐서 되돌릴 수 없어요.'), findsOneWidget);
    });

    homeTest('요약으로 바뀐 메모를 고정하면 요약이 메모로 저장되고 요약 칸은 비운다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      final saved = (await MemoStorage.getList()).single;
      expect(saved.memo, summary);
      expect(saved.summary, isNull); // 메모와 같은 내용을 한 번 더 저장하지 않는다
      expect(saved.category, '학교');
      expect(shown.where((c) => c.method == 'show'), hasLength(1));
    });

    homeTest('되돌린 뒤 고정하면 원문이 메모로, 요약은 요약 칸에 저장된다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      final saved = (await MemoStorage.getList()).single;
      expect(saved.memo, long);
      expect(saved.summary, summary);
    });

    homeTest('요약이 없는 짧은 메모는 그대로 두고 분류만 적용한다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, '수학 숙제 하기');
      expect(memoText(tester), '수학 숙제 하기');
      expect(find.text('자동 정리를 적용했어요.'), findsOneWidget);
      expect(find.text('되돌리기'), findsNothing);
      expect(find.byKey(const Key('applied-analysis')), findsOneWidget);
    });

    homeTest('요약이 원문과 같으면 바꾸지 않는다', (tester) async {
      // 26~30자의 한 문장: 요약이 원문 그대로다.
      const same = '가나다라마바사아자차카타파하';
      final text = same + same;
      expect(classifyByRules(text, DateTime.now()).summary, text);
      await openHome(tester);
      await analyzeAndApplyOnly(tester, text);
      expect(memoText(tester), text);
      expect(find.text('되돌리기'), findsNothing);
    });

    homeTest('적용하고 예약 시각 확인: 메모가 요약으로 바뀌고 예약 시트가 열린다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, long);
      await tapAnalyze(tester);
      await tester.tap(find.text('적용하고 예약 시각 확인'));
      await tester.pumpAndSettle();
      expect(find.text('언제 고정할까요?'), findsOneWidget);
      expect(memoText(tester), summary);
    });

    homeTest('메모를 직접 다 지우면 되돌리기 토스트도 사라진다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      expect(find.text('되돌리기'), findsOneWidget);
      await typeMemo(tester, ''); // 글자를 모두 삭제
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsNothing);
      expect(find.text('새 메모를 요약으로 바꿨어요.'), findsNothing);
    });

    homeTest('요약을 고치면 되돌리기 토스트가 사라진다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await typeMemo(tester, '$summary 고침');
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsNothing);
    });

    homeTest('✕로 지워도 되돌리기 토스트가 사라진다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(memoText(tester), isEmpty);
      expect(find.text('되돌리기'), findsNothing);
    });

    homeTest('고정하면 되돌리기 토스트는 사라진다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.text('알림 고정하기'));
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsNothing);
    });

    homeTest('글자는 그대로이고 커서만 움직이면 토스트가 유지된다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      final controller = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!;
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('되돌리기'), findsOneWidget);
    });

    homeTest('되돌리기를 누르면 원문이 돌아오고 토스트는 닫힌다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.tap(find.byKey(const Key('toast-action')));
      await tester.pumpAndSettle();
      expect(memoText(tester), long);
      expect(find.text('되돌리기'), findsNothing);
    });

    homeTest('토스트가 저절로 사라진 뒤에는 다른 토스트를 건드리지 않는다', (tester) async {
      await openHome(tester);
      await analyzeAndApplyOnly(tester, long);
      await tester.pump(const Duration(seconds: 7)); // 6초짜리 토스트가 끝난다
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsNothing);
      // 전혀 다른 토스트가 떠 있는 상태에서 메모를 지워도 그 토스트는 그대로다.
      showAppToast(tester.element(find.byType(HomeScreen)), '다른 안내 토스트');
      await tester.pump(const Duration(milliseconds: 300));
      await typeMemo(tester, '');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('다른 안내 토스트'), findsOneWidget);
    });

    homeTest('예약 시트를 그냥 닫으면 되돌리기가 뜬다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, long);
      await tapAnalyze(tester);
      await tester.tap(find.text('적용하고 예약 시각 확인'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // 시트 바깥을 눌러 닫기
      await tester.pumpAndSettle();
      expect(find.text('되돌리기'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pumpAndSettle();
      expect(memoText(tester), long);
    });
  });

  group('사진 글자 인식 뒤 AI 버튼 안내', () {
    const hintKey = Key('ai-hint');

    /// 사진으로 글자를 가져온 것처럼 흉내 낸다(카메라·ML Kit 없이).
    Future<void> readPhoto(WidgetTester tester, String? text) async {
      OcrService.debugReader = (_) async => text;
      addTearDown(() => OcrService.debugReader = null);
      await openMenu(tester);
      await tester.tap(find.text('사진으로 메모 가져오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('갤러리에서 선택'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    homeTest('글자를 가져오면 메모가 채워지고 안내가 뜬다', (tester) async {
      await openHome(tester);
      expect(find.byKey(hintKey), findsNothing);
      await readPhoto(tester, '사진 속 글자 한 줄');
      expect(find.text('사진으로부터 글자를 불러왔어요.'), findsOneWidget);
      expect(find.byKey(hintKey), findsOneWidget);
      expect(find.text('AI가 자동으로 분석해줘요!'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '사진 속 글자 한 줄',
      );
    });

    homeTest('긴 글을 불러오면 새 메모 카드가 글 길이에 맞춰 늘어난다', (tester) async {
      await openHome(tester);
      final before = tester.getSize(find.byType(InputCard)).height;
      final long = List.generate(20, (i) => '사진 속 문장 ${i + 1}').join('\n');
      await readPhoto(tester, long);
      await tester.pump(const Duration(milliseconds: 400));
      final after = tester.getSize(find.byType(InputCard)).height;
      expect(after, greaterThan(before + 10 * 26)); // 20줄이면 최소 6줄보다 14줄쯤 더 커진다
      expect(tester.takeException(), isNull); // 넘침 오류가 없다
      expect(find.byKey(const Key('ai-hint')), findsOneWidget); // 안내 말풍선도 그대로
      // 글 전체가 입력창에 들어 있다.
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        long,
      );
    });

    homeTest('아주 긴 글이어도 맨 아래까지 스크롤하면 알림 지우기 버튼이 화면 끝에 붙지 않고 아래 여백이 남는다', (
      tester,
    ) async {
      await openHome(tester);
      await typeMemo(
        tester,
        List.generate(40, (i) => '긴 메모 ${i + 1}').join('\n'),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      // 화면(가장 바깥 스크롤)을 맨 아래까지 내린다.
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final screenHeight = tester.getSize(find.byType(Scaffold)).height;
      final cancel = tester.getRect(find.byType(CancelButton));
      expect(cancel.bottom, lessThanOrEqualTo(screenHeight - 15));
      expect(tester.takeException(), isNull);
    });

    homeTest('글이 늘었다 줄어도 아래 문구는 같은 자리에 있다', (tester) async {
      await openHome(tester);
      // 시작 애니메이션(0.9초)이 끝나야 문구 높이가 정해진다
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
      final footer = find.byKey(const Key('home-footer'));
      expect(footer, findsOneWidget);
      final before = tester.getCenter(footer);
      await typeMemo(
        tester,
        List.generate(40, (i) => '긴 메모 ${i + 1}').join('\n'),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.getCenter(footer), before); // 늘어나도 따라 움직이지 않는다
      // 본문이 문구 자리까지 내려오면 투명 버튼 뒤로 비치지 않게 숨는다
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: footer, matching: find.byType(AnimatedOpacity)),
          )
          .opacity;
      expect(opacity(), 0);
      await typeMemo(tester, '');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.getCenter(footer), before);
      expect(opacity(), 1); // 줄어들면 같은 자리에서 다시 보인다
    });

    homeTest('앱을 처음 열 때 문구가 본문과 함께 나타난다(한참 뒤에 뿅 나타나지 않는다)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            currentMode: ThemeMode.light,
            onThemeChanged: (_) {},
          ),
        ),
      );
      // 시작 애니메이션(0.9초)이 한창인 0.3초 시점
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const Key('home-footer')), findsOneWidget);
      // 본문처럼 아래에서 올라오는 중이다(끝난 자리보다 아래에 있다가 올라와서 멈춘다)
      final early = tester.getCenter(find.byKey(const Key('home-footer')));
      final bodyEarly = tester.getTopLeft(find.byType(InputCard)).dy;
      await tester.pump(const Duration(seconds: 2));
      final settled = tester.getCenter(find.byKey(const Key('home-footer')));
      final bodySettled = tester.getTopLeft(find.byType(InputCard)).dy;
      expect(early.dy, greaterThan(settled.dy + 2));
      // 올라온 양이 본문(입력창)이 올라온 양과 같다
      expect(early.dy - settled.dy, closeTo(bodyEarly - bodySettled, 1.5));
    });

    homeTest('공백만 있을 때도 ✕를 누르면 바로 비워진다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '   \n  ');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
    });

    homeTest('짧은 글을 불러오면 카드 크기는 그대로다', (tester) async {
      await openHome(tester);
      final before = tester.getSize(find.byType(InputCard)).height;
      await readPhoto(tester, '한 줄');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.getSize(find.byType(InputCard)).height,
        closeTo(before, 0.5),
      );
    });

    homeTest('직접 입력만으로는 안내가 뜨지 않는다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '직접 쓴 메모');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(hintKey), findsNothing);
    });

    homeTest('글자를 못 찾았거나 사진 선택을 취소하면 안내가 없다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, ''); // 글자 없음
      expect(find.byKey(hintKey), findsNothing);
      await readPhoto(tester, null); // 취소
      expect(find.byKey(hintKey), findsNothing);
    });

    homeTest('✨를 누르면 안내가 사라지고 AI 정리가 시작된다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '내일 오후 3시 치과 예약하기');
      await tester.tap(find.byKey(const Key('card-analyze')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.byKey(hintKey), findsNothing);
      expect(find.text('자동 정리'), findsOneWidget); // 결과 시트
    });

    homeTest('말풍선을 눌러도 AI 정리는 시작되지 않고 안내도 그대로다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '내일 오후 3시 치과 예약하기');
      await tester.tap(find.byKey(hintKey), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('자동 정리'), findsNothing);
      expect(find.byKey(hintKey), findsOneWidget);
    });

    homeTest('아무것도 안 해도 12초 뒤에는 저절로 사라진다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '사진 속 글자');
      await tester.pump(const Duration(seconds: 10));
      expect(find.byKey(hintKey), findsOneWidget); // 아직
      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(hintKey), findsNothing);
    });

    homeTest('메모를 지우면 사라지고 다시 입력해도 되살아나지 않는다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '사진 속 글자');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('지우기')); // 확인 창
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(hintKey), findsNothing);
      await typeMemo(tester, '새로 쓴 메모');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(hintKey), findsNothing);
    });

    homeTest('고정하면 사라지고 다음 메모에는 나오지 않는다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '사진 속 글자');
      await tester.tap(find.text('알림 고정하기'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(hintKey), findsNothing);
      await typeMemo(tester, '다음 메모');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(hintKey), findsNothing);
    });

    homeTest('사진을 또 가져오면 12초가 다시 시작된다', (tester) async {
      await openHome(tester);
      await readPhoto(tester, '첫 번째');
      await tester.pump(const Duration(seconds: 8));
      await readPhoto(tester, '두 번째');
      await tester.tap(find.byKey(const Key('toast-action'))); // 기존 메모 교체 적용
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 8)); // 첫 안내 기준이면 이미 꺼졌을 시점
      expect(find.byKey(hintKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(hintKey), findsNothing);
    });
  });

  group('사진 글자 vs 이미 쓴 메모', () {
    String memoText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).first).controller!.text;
    Future<void> photo(WidgetTester tester, String text) async {
      OcrService.debugReader = (_) async => text;
      addTearDown(() => OcrService.debugReader = null);
      await openMenu(tester);
      await tester.tap(find.text('사진으로 메모 가져오기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('갤러리에서 선택'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    homeTest('글이 있으면 바로 바꾸지 않고 빨간 토스트로 묻는다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '쓰던 메모');
      await photo(tester, '사진 글자');
      expect(find.text('기존 메모를 지우고 불러오시겠습니까?'), findsOneWidget);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
        AppColors.danger,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('toast-action')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '적용',
      );
      expect(memoText(tester), '쓰던 메모'); // 아직 그대로
      expect(find.byKey(const Key('ai-hint')), findsNothing);
    });

    homeTest('적용을 누르면 사진 글자로 대체되고 안내가 뜬다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '쓰던 메모');
      await photo(tester, '사진 글자');
      await tester.tap(find.byKey(const Key('toast-action')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(memoText(tester), '사진 글자');
      expect(find.byKey(const Key('ai-hint')), findsOneWidget);
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // 앞 토스트가 닫힌 뒤 다음 토스트
      expect(find.text('사진으로부터 글자를 불러왔어요.'), findsOneWidget);
    });

    homeTest('누르지 않으면 메모는 그대로이고 안내도 없다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '쓰던 메모');
      await photo(tester, '사진 글자');
      await tester.pump(const Duration(seconds: 9));
      expect(memoText(tester), '쓰던 메모');
      expect(find.byKey(const Key('ai-hint')), findsNothing);
    });

    homeTest('공백뿐인 메모는 묻지 않고 바로 채운다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '  ');
      await photo(tester, '사진 글자');
      expect(find.text('기존 메모를 지우고 불러오시겠습니까?'), findsNothing);
      expect(memoText(tester), '사진 글자');
    });
  });

  group('빨간 ✕: 새 메모 지우기 확인', () {
    String memoText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    homeTest('누르면 바로 지우지 않고 안내 창에 지울 글을 보여준다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '지울 메모 내용');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      expect(find.text('새 메모 지우기'), findsOneWidget);
      expect(find.text('작성 중인 메모를 지울까요?\n지우면 되돌릴 수 없어요.'), findsOneWidget);
      expect(find.byKey(const Key('clear-memo-preview')), findsOneWidget);
      expect(find.text('지울 메모 내용'), findsNWidgets(2)); // 입력창 + 미리보기
      expect(memoText(tester), '지울 메모 내용'); // 아직 그대로
    });

    homeTest('취소하면 메모가 그대로이고 버튼도 남아 있다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '지울 메모 내용');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(memoText(tester), '지울 메모 내용');
      expect(find.text('새 메모 지우기'), findsNothing);
      expect(await MemoStorage.getCurrent(), '지울 메모 내용');
    });

    homeTest('안내 창 바깥을 눌러도 지워지지 않는다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '지울 메모 내용');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(memoText(tester), '지울 메모 내용');
    });

    homeTest('지우기를 누르면 메모와 임시 저장이 비워진다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '지울 메모 내용');
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(memoText(tester), isEmpty);
      expect(await MemoStorage.getCurrent() ?? '', isEmpty);
      expect(find.text('새 메모 지우기'), findsNothing);
    });

    homeTest('분석을 적용한 메모를 지우면 적용 표시도 사라진다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, memo);
      await tapAnalyze(tester);
      await tester.tap(find.text('적용만 하기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('applied-analysis')), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('지우기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('applied-analysis')), findsNothing);
    });

    homeTest('긴 메모는 미리보기를 3줄로 줄여 보여준다', (tester) async {
      await openHome(tester);
      await typeMemo(tester, '아주 긴 메모 ' * 40);
      await tester.tap(find.byKey(const Key('clear-memo')));
      await tester.pumpAndSettle();
      final preview = tester.widget<Text>(
        find.byKey(const Key('clear-memo-preview')),
      );
      expect(preview.maxLines, 3);
      expect(preview.overflow, TextOverflow.ellipsis);
    });
  });
}

/// 적용 표시 위젯을 타입으로 찾기 위한 별칭.
typedef AppliedHost = AppliedAnalysisChips;
