import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_analysis.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/screens/settings_screen.dart';
import 'package:notimemo/storage/ai_storage.dart';
import 'package:notimemo/storage/settings_storage.dart';
import 'package:notimemo/utils/due_parser.dart';
import 'package:notimemo/widgets/analysis_sheet.dart';
import 'package:notimemo/widgets/app_dialogs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 버튼을 눌러 [open]이 만드는 시트·다이얼로그를 여는 최소 화면.
Widget host(Future<void> Function(BuildContext) open) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => open(context),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
}

MemoAnalysis analysis({
  AnalysisSource source = AnalysisSource.ai,
  FallbackReason? reason,
  String summary = '치과 예약',
  ParsedDue? due,
  MemoPriority priority = MemoPriority.high,
}) => MemoAnalysis(
  category: '약속',
  priority: priority,
  summary: summary,
  due: due,
  source: source,
  fallbackReason: reason,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('동의 다이얼로그', () {
    testWidgets('내용 안내: 외부 전송, 전송 항목, 끌 수 있음', (tester) async {
      await tester.pumpWidget(host((c) async => showAiConsentDialog(c)));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('AI 자동 정리'), findsOneWidget);
      expect(find.textContaining('외부 서버로 전송'), findsOneWidget);
      expect(find.textContaining('Cloudflare'), findsOneWidget);
      expect(find.textContaining('언제든 끌 수 있어요'), findsOneWidget);
      expect(find.textContaining('기본 분석은 쓸 수 있어요'), findsOneWidget);
      expect(find.byKey(const Key('consent-note')), findsOneWidget);
      expect(find.textContaining('하루에 기기당 20회'), findsOneWidget);
      expect(find.textContaining('참고: VPN을 쓰는 중이면'), findsOneWidget);
      expect(find.textContaining('VPN 제외 앱에 추가'), findsOneWidget);
    });

    testWidgets('동의하고 사용 → true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        host((c) async => result = await showAiConsentDialog(c)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('동의하고 사용'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('AI 없이 사용 → false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        host((c) async => result = await showAiConsentDialog(c)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 없이 사용'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('바깥을 눌러 닫으면 null(아무것도 정하지 않음)', (tester) async {
      var called = false;
      bool? result = true;
      await tester.pumpWidget(
        host((c) async {
          called = true;
          result = await showAiConsentDialog(c);
        }),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
    });
  });

  group('결과 시트', () {
    Future<AnalysisDecision?> open(WidgetTester tester, MemoAnalysis a) async {
      AnalysisDecision? decision;
      await tester.pumpWidget(
        host((c) async => decision = await showAnalysisSheet(c, a)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return decision;
    }

    testWidgets('AI 결과: 배지, 카테고리, 우선순위, 요약, 예약 시각', (tester) async {
      await open(
        tester,
        analysis(due: ParsedDue(DateTime(2026, 10, 2, 15), hasTime: true)),
      );
      expect(find.text('AI 분석'), findsOneWidget);
      expect(find.byKey(const Key('fallback-message')), findsNothing);
      expect(find.text('약속'), findsOneWidget);
      expect(find.text('우선순위 높음'), findsOneWidget);
      expect(find.text('치과 예약'), findsOneWidget);
      expect(find.text('10월 2일 (금) 오후 3시'), findsOneWidget);
      expect(find.text('적용하고 예약 시각 확인'), findsOneWidget);
      expect(find.text('적용만 하기'), findsOneWidget);
    });

    testWidgets('폴백 결과: 기본 분석 배지와 이유 안내', (tester) async {
      await open(
        tester,
        analysis(source: AnalysisSource.rules, reason: FallbackReason.offline),
      );
      expect(find.text('기본 분석'), findsOneWidget);
      expect(find.text('AI 분석'), findsNothing);
      expect(find.text('인터넷에 연결되지 않아 기본 분석으로 정리했어요.'), findsOneWidget);
      expect(find.textContaining('VPN'), findsNothing); // VPN 안내는 동의 창에만 둔다
    });

    testWidgets('요약이 있으면 "적용하면 메모가 요약으로 바뀐다"는 안내가 보인다', (tester) async {
      await open(tester, analysis());
      expect(find.byKey(const Key('summary-replace-note')), findsOneWidget);
      expect(find.textContaining('요약으로 바뀌어요'), findsOneWidget);
      expect(find.textContaining('되돌리기'), findsOneWidget);
    });

    testWidgets('요약이 없으면 그 안내도 없다', (tester) async {
      await open(tester, analysis(summary: ''));
      expect(find.byKey(const Key('summary-replace-note')), findsNothing);
    });

    testWidgets('요약이 비면 요약 항목을 숨기고, 시각이 없으면 예약 항목도 숨긴다', (tester) async {
      await open(tester, analysis(summary: ''));
      expect(find.text('요약'), findsNothing);
      expect(find.text('예약 시각 제안'), findsNothing);
      expect(find.text('적용'), findsOneWidget);
      expect(find.text('적용하고 예약 시각 확인'), findsNothing);
    });

    testWidgets('시각을 못 찾은 날짜만의 제안은 9시로 채웠다고 알린다', (tester) async {
      await open(
        tester,
        analysis(due: ParsedDue(DateTime(2026, 10, 5, 9), hasTime: false)),
      );
      expect(find.textContaining('오전 9시로 채웠어요'), findsOneWidget);
    });

    testWidgets('시각이 명시되면 9시 안내가 없다', (tester) async {
      await open(
        tester,
        analysis(due: ParsedDue(DateTime(2026, 10, 2, 15), hasTime: true)),
      );
      expect(find.textContaining('오전 9시로 채웠어요'), findsNothing);
    });

    testWidgets('적용하고 예약 → applyAndSchedule', (tester) async {
      AnalysisDecision? decision;
      final a = analysis(
        due: ParsedDue(DateTime(2026, 10, 2, 15), hasTime: true),
      );
      await tester.pumpWidget(
        host((c) async => decision = await showAnalysisSheet(c, a)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용하고 예약 시각 확인'));
      await tester.pumpAndSettle();
      expect(decision, AnalysisDecision.applyAndSchedule);
    });

    testWidgets('적용만 하기 → apply', (tester) async {
      AnalysisDecision? decision;
      final a = analysis(
        due: ParsedDue(DateTime(2026, 10, 2, 15), hasTime: true),
      );
      await tester.pumpWidget(
        host((c) async => decision = await showAnalysisSheet(c, a)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용만 하기'));
      await tester.pumpAndSettle();
      expect(decision, AnalysisDecision.apply);
    });

    testWidgets('예약 시각이 없을 때 적용 → apply', (tester) async {
      AnalysisDecision? decision;
      final a = analysis();
      await tester.pumpWidget(
        host((c) async => decision = await showAnalysisSheet(c, a)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('적용'));
      await tester.pumpAndSettle();
      expect(decision, AnalysisDecision.apply);
    });

    testWidgets('아래로 끌어 닫으면 null(적용 안 함)', (tester) async {
      AnalysisDecision? decision = AnalysisDecision.apply;
      final a = analysis();
      await tester.pumpWidget(
        host((c) async => decision = await showAnalysisSheet(c, a)),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // 시트 바깥(배경)
      await tester.pumpAndSettle();
      expect(decision, isNull);
    });

    testWidgets('모든 폴백 이유가 시트에 표시된다', (tester) async {
      for (final reason in FallbackReason.values) {
        await tester.pumpWidget(const SizedBox()); // 이전 시트 정리
        await open(
          tester,
          analysis(source: AnalysisSource.rules, reason: reason),
        );
        expect(
          find.byKey(const Key('fallback-message')),
          findsOneWidget,
          reason: '$reason',
        );
        expect(find.text('기본 분석'), findsOneWidget, reason: '$reason');
      }
    });
  });

  group('설정 화면의 AI 스위치', () {
    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: '알림메모',
        packageName: 'com.example.notimemo',
        version: '3.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    Future<void> openSettings(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            currentMode: ThemeMode.light,
            onThemeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    bool switchValue(WidgetTester tester) =>
        tester.widget<Switch>(find.byKey(const Key('ai-switch'))).value;

    testWidgets('진동 스위치: 기본 켜짐, 끄면 저장된다', (tester) async {
      await openSettings(tester);
      Switch sw() =>
          tester.widget<Switch>(find.byKey(const Key('vibration-switch')));
      expect(sw().value, isTrue);
      await tester.tap(find.byKey(const Key('vibration-switch')));
      await tester.pumpAndSettle();
      expect(sw().value, isFalse);
      expect(await SettingsStorage.getVibration(), isFalse);
    });

    testWidgets('앱 정보에 앱 이름 줄은 없다', (tester) async {
      await openSettings(tester);
      expect(find.text('앱 이름'), findsNothing);
      expect(find.text('버전'), findsOneWidget);
    });

    testWidgets('처음에는 꺼져 있다', (tester) async {
      await openSettings(tester);
      expect(switchValue(tester), isFalse);
      expect(find.textContaining('꺼져 있어요'), findsOneWidget);
    });

    testWidgets('이미 동의한 상태면 켜져 있다', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openSettings(tester);
      expect(switchValue(tester), isTrue);
      expect(find.textContaining('외부 서버(Cloudflare)로 전송'), findsOneWidget);
    });

    testWidgets('켜면 동의 창이 뜨고, 동의하면 켜진다', (tester) async {
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('ai-switch')));
      await tester.pumpAndSettle();
      expect(find.text('AI 자동 정리'), findsWidgets);
      expect(find.textContaining('외부 서버로 전송'), findsOneWidget);
      await tester.tap(find.text('동의하고 사용'));
      await tester.pumpAndSettle();
      expect(switchValue(tester), isTrue);
      expect(await AiStorage.getConsent(), isTrue);
    });

    testWidgets('켜려다 AI 없이 사용을 고르면 꺼진 채로 거부가 기록된다', (tester) async {
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('ai-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI 없이 사용'));
      await tester.pumpAndSettle();
      expect(switchValue(tester), isFalse);
      expect(await AiStorage.getConsent(), isFalse);
    });

    testWidgets('동의 창을 그냥 닫으면 아무것도 바뀌지 않는다', (tester) async {
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('ai-switch')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(switchValue(tester), isFalse);
      expect(await AiStorage.getConsent(), isNull);
    });

    testWidgets('끄면 바로 꺼지고 거부가 기록된다(동의 창 없음)', (tester) async {
      SharedPreferences.setMockInitialValues({'ai_consent': true});
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('ai-switch')));
      await tester.pumpAndSettle();
      expect(find.text('동의하고 사용'), findsNothing);
      expect(switchValue(tester), isFalse);
      expect(await AiStorage.getConsent(), isFalse);
    });
  });
}
