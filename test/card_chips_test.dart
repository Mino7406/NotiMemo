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

    testWidgets('위아래가 대칭이다: ✕가 위 테두리에서 떨어진 만큼 🕒가 아래 테두리에서 떨어진다', (
      tester,
    ) async {
      // 카드가 화면 높이로 늘어나지 않고 최소 크기(6줄)인 상태로 그린다.
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = TextEditingController(text: '메모');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: InputCard(
                  controller: c,
                  isDark: false,
                  textColor: Colors.black,
                  subColor: Colors.grey,
                  onClear: () {},
                  onAnalyze: () {},
                  onSchedule: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(InputCard));
      final top = rectOf(tester, clearKey).top - card.top;
      final bottom = card.bottom - rectOf(tester, scheduleKey).bottom;
      expect(bottom, closeTo(top, 1.5));
      // 글이 길어져 카드가 늘어나도 대칭은 그대로다.
      c.text = List.generate(25, (i) => '줄 ${i + 1}').join('\n');
      await tester.pumpAndSettle();
      final grown = tester.getRect(find.byType(InputCard));
      expect(
        grown.bottom - rectOf(tester, scheduleKey).bottom,
        closeTo(rectOf(tester, clearKey).top - grown.top, 1.5),
      );
    });

    testWidgets('✕는 위쪽에, ✨·🕒는 아래쪽에 있고 ✨·🕒 사이는 8px다', (tester) async {
      await openCard(tester, text: '메모');
      final r = [
        for (final k in [clearKey, analyzeKey, scheduleKey]) rectOf(tester, k),
      ];
      final separation = r[1].top - r[0].bottom; // ✕ ↔ ✨
      final together = r[2].top - r[1].bottom; // ✨ ↔ 🕒
      expect(together, closeTo(8, 0.6));
      // 분리: ✕ 아래 간격이 ✨·🕒 사이 간격의 3배 넘게 크다.
      expect(separation, greaterThan(together * 3));
    });

    testWidgets('✨·🕒는 서로 붙어 한 덩어리로 보인다', (tester) async {
      await openCard(tester, text: '메모');
      final analyze = rectOf(tester, analyzeKey);
      final schedule = rectOf(tester, scheduleKey);
      final clear = rectOf(tester, clearKey);
      // ✕에서 ✨까지가 ✨에서 🕒까지보다 훨씬 멀다 = 눈으로 구분되는 두 그룹
      expect(
        analyze.top - clear.bottom,
        greaterThan((schedule.top - analyze.bottom) * 3),
      );
    });

    testWidgets('세 버튼 모두 같은 세로줄(오른쪽 끝)에 정렬된다', (tester) async {
      await openCard(tester, text: '메모');
      final lefts = [
        for (final k in [clearKey, analyzeKey, scheduleKey])
          rectOf(tester, k).left,
      ];
      expect(lefts[1], closeTo(lefts[0], 0.5));
      expect(lefts[2], closeTo(lefts[0], 0.5));
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

    testWidgets('버튼이 둘일 때 ✕는 위, ✨는 아래 테두리에서 같은 거리에 있다', (tester) async {
      await openCard(tester, text: '메모', schedule: false);
      final card = tester.getRect(find.byType(InputCard));
      final first = rectOf(tester, clearKey);
      final second = rectOf(tester, analyzeKey);
      expect(first.top - card.top, closeTo(13, 1));
      expect(card.bottom - second.bottom, closeTo(13, 1)); // 위(13)와 같다
      expect(second.top - first.bottom, greaterThan(24)); // ✕와 떨어져 있다
    });

    testWidgets('✨ 없이 🕒만 있어도 ✕와 떨어져 아래쪽에 있다', (tester) async {
      await openCard(tester, text: '메모', analyze: false);
      final first = rectOf(tester, clearKey);
      final second = rectOf(tester, scheduleKey);
      final card = tester.getRect(find.byType(InputCard));
      expect(card.bottom - second.bottom, closeTo(13, 1));
      expect(second.top - first.bottom, greaterThan(24));
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

    testWidgets('✨·🕒는 카드 오른쪽 바깥에서 옆으로 미끄러져 들어온다(차례로)', (tester) async {
      final c = await openCard(tester);
      // 최종 위치를 먼저 기록한다.
      c.text = '메모';
      await tester.pumpAndSettle();
      final finalRect = {
        for (final k in [clearKey, analyzeKey, scheduleKey])
          k: rectOf(tester, k),
      };
      final card = tester.getRect(find.byType(InputCard));
      c.text = '';
      await tester.pumpAndSettle();
      c.text = '메모';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final midAnalyze = rectOf(tester, analyzeKey);
      final midSchedule = rectOf(tester, scheduleKey);

      // ✕는 제자리에서 커진다(바운스로 크기가 변해도 중심은 그대로).
      expect(
        rectOf(tester, clearKey).center,
        finalRect[clearKey]!.center.translate(0, 0),
      );
      // ✨·🕒는 세로 위치는 이미 최종 자리이고, 가로로만 오른쪽에 치우쳐 있다(옆에서 들어온다).
      expect(midAnalyze.top, closeTo(finalRect[analyzeKey]!.top, 0.5));
      expect(midSchedule.top, closeTo(finalRect[scheduleKey]!.top, 0.5));
      expect(midAnalyze.left, greaterThan(finalRect[analyzeKey]!.left + 4));
      expect(midSchedule.left, greaterThan(finalRect[scheduleKey]!.left + 4));
      // 시작 지점은 카드 오른쪽 가장자리 밖이라 처음에는 둘 다 카드 밖(오른쪽)에 있다.
      final startOffset = midAnalyze.left - finalRect[analyzeKey]!.left;
      expect(startOffset, greaterThan(40));
      expect(
        midSchedule.left - finalRect[scheduleKey]!.left,
        closeTo(startOffset, 0.5),
      );

      // 0.3초 시점: ✨는 이미 들어오는 중이고 🕒는 아직 출발 전이다 = 차례로 들어온다.
      await tester.pump(const Duration(milliseconds: 140));
      final lagAnalyze =
          rectOf(tester, analyzeKey).left - finalRect[analyzeKey]!.left;
      final lagSchedule =
          rectOf(tester, scheduleKey).left - finalRect[scheduleKey]!.left;
      expect(lagAnalyze, lessThan(startOffset - 3)); // ✨는 움직이는 중
      expect(lagSchedule, closeTo(startOffset, 1.0)); // 🕒는 아직 제자리(시작 위치)
      expect(lagSchedule, greaterThan(lagAnalyze));

      await tester.pumpAndSettle();
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(rectOf(tester, k).topLeft, finalRect[k]!.topLeft);
      }
      // 끝나면 모두 카드 안쪽에 들어와 있다.
      for (final k in [clearKey, analyzeKey, scheduleKey]) {
        expect(card.contains(rectOf(tester, k).center), isTrue, reason: '$k');
      }
    });

    testWidgets('✕는 옆에서 오지 않고 제자리에서 커지며 나타난다', (tester) async {
      final c = await openCard(tester);
      c.text = '메모';
      await tester.pumpAndSettle();
      final finalCenter = rectOf(tester, clearKey).center;
      c.text = '';
      await tester.pumpAndSettle();
      c.text = '메모';
      await tester.pump();
      for (final ms in [30, 60, 100]) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(
          rectOf(tester, clearKey).center.dx,
          closeTo(finalCenter.dx, 0.5),
          reason: '${ms}ms',
        );
        expect(
          rectOf(tester, clearKey).center.dy,
          closeTo(finalCenter.dy, 0.5),
          reason: '${ms}ms',
        );
      }
    });

    testWidgets('✨·🕒는 위아래로는 움직이지 않는다(✕ 자리에서 내려오지 않는다)', (tester) async {
      final c = await openCard(tester, text: '메모');
      final top = rectOf(tester, analyzeKey).top;
      c.text = '';
      await tester.pumpAndSettle();
      c.text = '메모';
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(rectOf(tester, analyzeKey).top, closeTo(top, 0.5));
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

    testWidgets('말풍선을 눌러도 AI 정리는 시작되지 않는다(✨ 버튼으로만)', (tester) async {
      final taps = Taps();
      await openCard(tester, taps: taps, text: '메모', hint: true);
      await tester.tap(find.byKey(hintKey), warnIfMissed: false);
      expect(taps.analyze, 0);
      await tester.tap(find.byKey(const Key('card-analyze')));
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
