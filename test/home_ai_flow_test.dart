import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/screens/home_screen.dart';
import 'package:notimemo/storage/ai_storage.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:notimemo/storage/tutorial_storage.dart';
import 'package:notimemo/widgets/home_widgets.dart' show AppliedAnalysisChips;
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
    await tester.pump(const Duration(seconds: 9));
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

  homeTest('적용 없이 고정하면 카테고리·우선순위는 기본값', (tester) async {
    await openHome(tester);
    await typeMemo(tester, memo);
    await tester.tap(find.text('알림 고정하기'));
    await tester.pumpAndSettle();
    final entry = (await MemoStorage.getList()).single;
    expect(entry.category, isNull);
    expect(entry.priority, MemoPriority.normal);
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
    expect(entry.category, isNull);
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
      SharedPreferences.setMockInitialValues({'ai_consent': false, 'tutorial_seen': true});
      await openHome(tester);
      await typeMemo(tester, memo);
      await tapAnalyze(tester);
      expect(find.textContaining('외부 서버로 전송'), findsNothing);
      expect(find.text('기본 분석'), findsOneWidget);
    });
  });

  group('튜토리얼', () {
    homeTest('처음 설치하면 튜토리얼이 뜨고, 끝까지 넘기면 본 것으로 저장된다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openHome(tester);
      expect(find.text('메모를 알림창에 고정해요'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const Key('tutorial-next')));
        await tester.pumpAndSettle();
      }
      expect(find.text('시작하기'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menu-button')), findsOneWidget);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('건너뛰기를 눌러도 본 것으로 저장된다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openHome(tester);
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pumpAndSettle();
      expect(find.text('메모를 알림창에 고정해요'), findsNothing);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('이미 쓰던 사용자(히스토리 있음)에게는 뜨지 않는다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await MemoStorage.saveList([MemoEntry(id: 'a', memo: '옛 메모', time: 1)]);
      await openHome(tester);
      expect(find.text('메모를 알림창에 고정해요'), findsNothing);
      expect(await TutorialStorage.getSeen(), isTrue);
    });

    homeTest('메뉴의 튜토리얼로 다시 볼 수 있다', (tester) async {
      await openHome(tester);
      expect(find.text('메모를 알림창에 고정해요'), findsNothing);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('menu-tutorial')));
      await tester.pumpAndSettle();
      expect(find.text('메모를 알림창에 고정해요'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tutorial-skip')));
      await tester.pumpAndSettle();
      expect(find.text('메모를 알림창에 고정해요'), findsNothing);
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
}

/// 적용 표시 위젯을 타입으로 찾기 위한 별칭.
typedef AppliedHost = AppliedAnalysisChips;
