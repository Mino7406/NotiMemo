import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/widgets/home_widgets.dart';

const clearKey = Key('clear-memo');
const analyzeKey = Key('card-analyze');
const scheduleKey = Key('card-schedule');

class Taps {
  int clear = 0, analyze = 0, schedule = 0;
}

Widget host(
  TextEditingController c,
  Taps taps, {
  bool analyze = true,
  bool schedule = true,
  bool analyzing = false,
  bool hint = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: InputCard(
          controller: c,
          isDark: false,
          textColor: Colors.black,
          subColor: Colors.grey,
          onClear: () => taps.clear++,
          onAnalyze: analyze ? () => taps.analyze++ : null,
          isAnalyzing: analyzing,
          showAiHint: hint,
          onSchedule: schedule ? () => taps.schedule++ : null,
        ),
      ),
    ),
  );
}

/// 칩의 현재 투명도(애니메이션 도중 값).
double opacityOf(WidgetTester tester, Key key) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

/// 화면에 실제로 그려지는 버튼 몸체의 위치. 슬라이드·확대 같은 애니메이션 변환이 적용된 값이다
/// (키가 붙은 바깥 위젯의 레이아웃 위치는 변환의 영향을 받지 않는다).
Rect rectOf(WidgetTester tester, Key key) => tester.getRect(
  find.descendant(of: find.byKey(key), matching: find.byType(Container)).first,
);

Future<TextEditingController> openCard(
  WidgetTester tester, {
  Taps? taps,
  String text = '',
  bool analyze = true,
  bool schedule = true,
  bool analyzing = false,
  bool hint = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final c = TextEditingController(text: text);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    host(
      c,
      taps ?? Taps(),
      analyze: analyze,
      schedule: schedule,
      analyzing: analyzing,
      hint: hint,
    ),
  );
  // 분석 중이거나 안내 말풍선이 깜빡이는 중이면 애니메이션이 끝나지 않아 pumpAndSettle이 못 끝난다.
  if (analyzing || hint) {
    await tester.pump(const Duration(seconds: 1));
  } else {
    await tester.pumpAndSettle();
  }
  return c;
}

void main() {
  group('크기와 배치', () {
    testWidgets('버튼은 34×34이고 카드 오른쪽 위 안쪽 여백에 놓인다', (tester) async {
      await openCard(tester, text: '메모');
      final card = tester.getRect(find.byType(InputCard));
      final r = [
        for (final k in [clearKey, analyzeKey, scheduleKey]) rectOf(tester, k),
      ];
      for (final rect in r) {
        expect(rect.width, 34);
        expect(rect.height, 34);
        expect(rect.left, r.first.left); // 한 줄로 정렬
      }
      // 오른쪽·위 여백은 카드 테두리(1px) + 안쪽 여백 12.
      expect(card.right - r.first.right, closeTo(13, 1));
      expect(r.first.top - card.top, closeTo(13, 1));
      // 세 버튼이 카드 안에 들어온다(아래로 넘치지 않는다).
      expect(r.last.bottom, lessThan(card.bottom - 12));
    });

    testWidgets('버튼 사이 간격은 8px로 일정하다', (tester) async {
      await openCard(tester, text: '메모');
      final r = [
        for (final k in [clearKey, analyzeKey, scheduleKey]) rectOf(tester, k),
      ];
      final gap1 = r[1].top - r[0].bottom;
      final gap2 = r[2].top - r[1].bottom;
      expect(gap1, closeTo(8, 0.6));
      expect(gap2, closeTo(8, 0.6));
      expect(gap1, lessThan(20)); // 카드 높이에 펴 놓던 때(약 46px)처럼 벌어지지 않는다
    });

    testWidgets('글자 입력 영역이 버튼에 가려지지 않는다', (tester) async {
      await openCard(tester, text: '메모');
      final field = tester.widget<TextField>(find.byType(TextField));
      final padding = field.decoration!.contentPadding! as EdgeInsets;
      final textRight =
          tester.getRect(find.byType(TextField)).right - padding.right;
      expect(textRight, lessThanOrEqualTo(rectOf(tester, clearKey).left));
    });

    testWidgets('✕만 있어도(다른 버튼 없음) 위쪽 여백 자리에 놓인다', (tester) async {
      await openCard(tester, text: '메모', analyze: false, schedule: false);
      final card = tester.getRect(find.byType(InputCard));
      expect(find.byKey(analyzeKey), findsNothing);
      expect(find.byKey(scheduleKey), findsNothing);
      expect(rectOf(tester, clearKey).top - card.top, closeTo(13, 1));
    });

    testWidgets('버튼이 둘일 때도 같은 간격으로 위에서부터 쌓인다', (tester) async {
      await openCard(tester, text: '메모', schedule: false);
      final card = tester.getRect(find.byType(InputCard));
      final first = rectOf(tester, clearKey);
      final second = rectOf(tester, analyzeKey);
      expect(first.top - card.top, closeTo(13, 1));
      expect(second.top - first.bottom, closeTo(8, 0.6));
    });
  });

  group('나타나는 순서 (✕ 먼저, 뒤이어 나머지가 슬라이드)', () {
    testWidgets('메모가 비어 있으면 모두 숨어 있고 눌러도 동작하지 않는다', (tester) async {
      final taps = Taps();
      await openCard(tester, taps: taps);
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(opacityOf(tester, k), 0, reason: '$k');
        await tester.tap(find.byKey(k), warnIfMissed: false);
      }
      expect(taps.clear + taps.analyze + taps.schedule, 0);
    });

    testWidgets('입력하면 ✕가 먼저 나타나고 ✨·🕒는 뒤따른다', (tester) async {
      final c = await openCard(tester);
      c.text = '메모';
      await tester.pump(); // 애니메이션 시작
      await tester.pump(const Duration(milliseconds: 120));
      expect(opacityOf(tester, clearKey), greaterThan(0.6)); // ✕는 벌써 보인다
      expect(
        opacityOf(tester, analyzeKey),
        lessThan(opacityOf(tester, clearKey)),
      );
      expect(
        opacityOf(tester, scheduleKey),
        lessThanOrEqualTo(opacityOf(tester, analyzeKey)),
      );
      expect(opacityOf(tester, scheduleKey), lessThan(0.2)); // 🕒는 아직 거의 안 보인다

      await tester.pump(const Duration(milliseconds: 200)); // 약 320ms
      expect(opacityOf(tester, clearKey), 1);
      expect(opacityOf(tester, analyzeKey), greaterThan(0));
      expect(opacityOf(tester, analyzeKey), lessThan(1));

      await tester.pumpAndSettle();
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(opacityOf(tester, k), 1);
      }
    });

    testWidgets('✨·🕒는 ✕ 자리에서 아래로 미끄러져 내려온다(차례로)', (tester) async {
      final c = await openCard(tester);
      // 최종 위치를 먼저 기록한다.
      c.text = '메모';
      await tester.pumpAndSettle();
      final finalTop = {
        for (final k in [clearKey, analyzeKey, scheduleKey])
          k: rectOf(tester, k).top,
      };
      c.text = '';
      await tester.pumpAndSettle();
      c.text = '메모';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      // 도중: ✕는 제자리, ✨·🕒는 아직 위(✕ 쪽)에 있다.
      // ✕는 커지면서 살짝 튀어나오므로(바운스) 크기와 무관한 중심 위치로 "제자리"를 본다.
      expect(
        rectOf(tester, clearKey).center.dy,
        closeTo(finalTop[clearKey]! + 17, 0.5),
      );
      final midAnalyze = rectOf(tester, analyzeKey).top;
      final midSchedule = rectOf(tester, scheduleKey).top;
      expect(midAnalyze, lessThan(finalTop[analyzeKey]! - 4));
      expect(midSchedule, lessThan(finalTop[scheduleKey]! - 4));
      // 🕒가 ✨보다 더 뒤처져(더 위에) 있다 = 차례로 내려온다.
      final lagAnalyze = finalTop[analyzeKey]! - midAnalyze;
      final lagSchedule = finalTop[scheduleKey]! - midSchedule;
      expect(lagSchedule, greaterThan(lagAnalyze));

      await tester.pumpAndSettle();
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(rectOf(tester, k).top, closeTo(finalTop[k]!, 0.5));
      }
    });

    testWidgets('메모를 지우면 한꺼번에 빠르게 사라지고 다시 눌리지 않는다', (tester) async {
      final taps = Taps();
      final c = await openCard(tester, taps: taps, text: '메모');
      c.clear();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(opacityOf(tester, k), 0, reason: '$k');
      }
      await tester.tap(find.byKey(clearKey), warnIfMissed: false);
      expect(taps.clear, 0);
    });

    testWidgets('사라졌다가 다시 입력하면 같은 순서로 다시 나타난다', (tester) async {
      final c = await openCard(tester, text: '메모');
      c.clear();
      await tester.pumpAndSettle();
      c.text = '다시';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(
        opacityOf(tester, clearKey),
        greaterThan(opacityOf(tester, analyzeKey)),
      );
      await tester.pumpAndSettle();
      expect(opacityOf(tester, scheduleKey), 1);
    });
  });

  group('동작', () {
    testWidgets('보이는 버튼은 눌러서 각각 동작한다', (tester) async {
      final taps = Taps();
      await openCard(tester, taps: taps, text: '메모');
      await tester.tap(find.byKey(clearKey));
      await tester.tap(find.byKey(analyzeKey));
      await tester.tap(find.byKey(scheduleKey));
      expect([taps.clear, taps.analyze, taps.schedule], [1, 1, 1]);
    });

    testWidgets('분석 중에는 로딩 표시가 나오고 ✨를 눌러도 다시 시작되지 않는다', (tester) async {
      final taps = Taps();
      await openCard(tester, taps: taps, text: '메모', analyzing: true);
      expect(
        find.descendant(
          of: find.byKey(analyzeKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(analyzeKey));
      expect(taps.analyze, 0);
    });

    testWidgets('툴팁이 있다', (tester) async {
      await openCard(tester, text: '메모');
      expect(find.byTooltip('새 메모 지우기'), findsOneWidget);
      expect(find.byTooltip('AI 자동 정리'), findsOneWidget);
      expect(find.byTooltip('예약 생성'), findsOneWidget);
    });
  });

  group('AI 안내 말풍선(사진 글자 인식 뒤)', () {
    const hintKey = Key('ai-hint');
    const hintOpacityKey = Key('ai-hint-opacity');

    double hintOpacity(WidgetTester tester) =>
        tester.widget<Opacity>(find.byKey(hintOpacityKey)).opacity;

    testWidgets('기본으로는 보이지 않는다', (tester) async {
      await openCard(tester, text: '메모');
      expect(find.byKey(hintKey), findsNothing);
    });

    testWidgets('켜면 안내 문구가 보인다', (tester) async {
      await openCard(tester, text: '메모', hint: true);
      expect(find.byKey(hintKey), findsOneWidget);
      expect(find.text('AI가 자동으로 분석해줘요!'), findsOneWidget);
    });

    testWidgets('✨ 버튼의 왼쪽, 같은 높이에서 버튼을 가리킨다', (tester) async {
      await openCard(tester, text: '메모', hint: true);
      final bubble = tester.getRect(find.byKey(hintKey));
      final chip = rectOf(tester, analyzeKey);
      // 가운데 높이가 같다(맥박으로 버튼이 커져도 중심은 같다).
      expect(bubble.center.dy, closeTo(chip.center.dy, 1.5));
      // 말풍선(과 가리키는 삼각형)이 버튼의 왼쪽에 있고 겹치지 않는다.
      expect(bubble.right, lessThanOrEqualTo(chip.left + 1));
      expect(chip.left - bubble.right, lessThan(12)); // 버튼 바로 옆
      // ✕·🕒를 가리지 않는다.
      expect(bubble.bottom, lessThan(rectOf(tester, scheduleKey).top));
      expect(bubble.top, greaterThan(rectOf(tester, clearKey).bottom));
    });

    testWidgets('반투명하게 깜빡인다(흐림 0.3 ~ 또렷 1.0을 오간다)', (tester) async {
      await openCard(tester, text: '메모', hint: true);
      final samples = <double>[];
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        samples.add(hintOpacity(tester));
      }
      final lo = samples.reduce((a, b) => a < b ? a : b);
      final hi = samples.reduce((a, b) => a > b ? a : b);
      expect(lo, lessThan(0.45)); // 충분히 흐려지고
      expect(
        lo,
        greaterThanOrEqualTo(AiHintBubble.minOpacity - 0.001),
      ); // 완전히 사라지진 않고
      expect(hi, greaterThan(0.9)); // 또렷해지며
      expect(hi, lessThanOrEqualTo(1.0));
      // 한 방향으로만 가지 않고 오르내린다(깜빡임).
      var turns = 0;
      for (var i = 2; i < samples.length; i++) {
        final up1 = samples[i - 1] > samples[i - 2];
        final up2 = samples[i] > samples[i - 1];
        if (up1 != up2) turns++;
      }
      expect(turns, greaterThanOrEqualTo(2));
    });

    testWidgets('✨ 버튼도 같은 박자로 커졌다 작아진다', (tester) async {
      await openCard(tester, text: '메모', hint: true);
      final widths = <double>[];
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        widths.add(rectOf(tester, analyzeKey).width);
      }
      expect(widths.reduce((a, b) => a < b ? a : b), closeTo(34, 0.5));
      expect(widths.reduce((a, b) => a > b ? a : b), greaterThan(38));
      // 안내가 없는 버튼(✕)은 가만히 있는다.
      expect(rectOf(tester, clearKey).width, closeTo(34, 0.5));
    });

    testWidgets('메모가 비어 있으면 숨는다', (tester) async {
      final c = await openCard(tester, text: '메모', hint: true);
      c.clear();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(hintKey), findsNothing);
      c.text = '다시';
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(hintKey), findsOneWidget);
    });

    testWidgets('✨ 버튼이 없는 카드에는 나오지 않는다', (tester) async {
      await openCard(tester, text: '메모', analyze: false, hint: true);
      expect(find.byKey(hintKey), findsNothing);
    });

    testWidgets('말풍선을 누르면 ✨를 누른 것과 같다', (tester) async {
      final taps = Taps();
      await openCard(tester, taps: taps, text: '메모', hint: true);
      await tester.tap(find.byKey(hintKey));
      expect(taps.analyze, 1);
    });

    testWidgets('끄면 깜빡임이 멈추고 말풍선과 맥박이 사라진다', (tester) async {
      final c = TextEditingController(text: '메모');
      addTearDown(c.dispose);
      await tester.binding.setSurfaceSize(const Size(420, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(c, Taps(), hint: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(hintKey), findsOneWidget);
      await tester.pumpWidget(host(c, Taps(), hint: false));
      await tester.pumpAndSettle(); // 반복 애니메이션이 끝났기 때문에 정상적으로 끝난다
      expect(find.byKey(hintKey), findsNothing);
      expect(rectOf(tester, analyzeKey).width, closeTo(34, 0.5));
    });
  });
}
