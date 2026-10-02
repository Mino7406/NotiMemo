import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/widgets/home_widgets.dart';

/// 글 길이에 맞춰 새 메모 카드가 늘어나는지(그리고 과하지 않게 부드러운지) 확인한다.
/// 한 줄 높이. 글자 크기 16 × 줄 간격 1.6 = 25.6이지만 실제로는 줄 상자가 반올림되어 26으로
/// 그려진다(테스트 환경에서 실측: 6줄 입력 영역 = 6×26 + 위 여백 10 = 166).
const lineHeight = 26.0;

String lines(int n) => List.generate(n, (i) => '줄 ${i + 1}').join('\n');

Widget host(TextEditingController c, {double width = 420}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: width - 40,
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

Future<TextEditingController> openCard(
  WidgetTester tester, {
  String text = '',
  double width = 420,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final c = TextEditingController(text: text);
  addTearDown(c.dispose);
  await tester.pumpWidget(host(c, width: width));
  await tester.pumpAndSettle();
  return c;
}

double cardHeight(WidgetTester tester) =>
    tester.getSize(find.byType(InputCard)).height;

double fieldHeight(WidgetTester tester) =>
    tester.getSize(find.byType(TextField)).height;

Future<double> settledHeight(
  WidgetTester tester,
  TextEditingController c,
  String text,
) async {
  c.text = text;
  await tester.pumpAndSettle();
  return cardHeight(tester);
}

void main() {
  group('최소 높이', () {
    testWidgets('빈 메모·짧은 글·6줄까지는 높이가 같다(전과 같은 크기)', (tester) async {
      final c = await openCard(tester);
      final empty = cardHeight(tester);
      expect(await settledHeight(tester, c, '짧은 글'), closeTo(empty, 0.5));
      expect(await settledHeight(tester, c, lines(6)), closeTo(empty, 0.5));
    });

    testWidgets('최소 입력 영역은 6줄 높이다', (tester) async {
      await openCard(tester);
      // 6줄 × 25.6 + 위쪽 안쪽 여백(10)
      expect(fieldHeight(tester), closeTo(6 * lineHeight + 10, 1.0));
    });
  });

  group('글 길이에 맞춰 늘어난다', () {
    testWidgets('6줄을 넘으면 넘은 줄 수만큼 늘어난다', (tester) async {
      final c = await openCard(tester);
      final base = cardHeight(tester);
      for (final n in [7, 10, 20, 40]) {
        final h = await settledHeight(tester, c, lines(n));
        expect(h, closeTo(base + (n - 6) * lineHeight, 2.0), reason: '$n줄');
      }
    });

    testWidgets('긴 글이 잘리지 않고 전부 들어간다(안에서 스크롤하지 않는다)', (tester) async {
      final c = await openCard(tester);
      c.text = lines(30);
      await tester.pumpAndSettle();
      // 입력 영역 높이가 30줄 전체 높이 이상이다.
      expect(fieldHeight(tester), greaterThanOrEqualTo(30 * lineHeight));
      expect(find.textContaining('줄 30'), findsOneWidget);
    });

    testWidgets('줄바꿈 없이 아주 긴 글도 자동으로 줄이 바뀌며 늘어난다', (tester) async {
      final c = await openCard(tester);
      final base = cardHeight(tester);
      final h = await settledHeight(tester, c, '긴 글입니다 ' * 150);
      expect(h, greaterThan(base + 5 * lineHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('글을 지우면 다시 최소 높이로 줄어든다', (tester) async {
      final c = await openCard(tester);
      final base = cardHeight(tester);
      expect(
        await settledHeight(tester, c, lines(25)),
        greaterThan(base + 10 * lineHeight),
      );
      expect(await settledHeight(tester, c, ''), closeTo(base, 0.5));
    });

    testWidgets('직접 줄을 입력하면 늘어나고 지우면 줄어든다', (tester) async {
      final c = await openCard(tester, text: lines(6));
      final base = cardHeight(tester);
      await tester.enterText(find.byType(TextField), lines(9));
      await tester.pumpAndSettle();
      expect(cardHeight(tester), closeTo(base + 3 * lineHeight, 2.0));
      await tester.enterText(find.byType(TextField), lines(7));
      await tester.pumpAndSettle();
      expect(cardHeight(tester), closeTo(base + lineHeight, 2.0));
      expect(c.text, lines(7));
    });
  });

  group('애니메이션은 짧고 부드럽다', () {
    testWidgets('늘어나는 도중에는 중간 높이를 거쳐 가고 0.25초 안에 끝난다', (tester) async {
      final c = await openCard(tester);
      final base = cardHeight(tester);
      c.text = lines(20);
      await tester.pump(); // 새 글로 다시 그림
      final start = cardHeight(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final early = cardHeight(tester);
      await tester.pump(const Duration(milliseconds: 80));
      final mid = cardHeight(tester);
      await tester.pump(const Duration(milliseconds: 120)); // 합계 260ms
      final end = cardHeight(tester);

      final target = base + 14 * lineHeight;
      expect(start, closeTo(base, 0.5)); // 시작은 기존 높이
      expect(early, greaterThan(start));
      expect(early, lessThan(target)); // 도중이다
      expect(mid, greaterThan(early)); // 점점 커진다
      expect(end, closeTo(target, 1.0)); // 0.26초면 다 끝난다 → 과하지 않다
    });

    testWidgets('한 번에 튀지 않는다(첫 프레임에 목표 높이가 아니다)', (tester) async {
      final c = await openCard(tester);
      final base = cardHeight(tester);
      c.text = lines(20);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(cardHeight(tester), lessThan(base + 14 * lineHeight - 20));
    });

    testWidgets('줄어들 때도 부드럽게 줄어든다', (tester) async {
      final c = await openCard(tester, text: lines(20));
      final tall = cardHeight(tester);
      c.text = '';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final during = cardHeight(tester);
      expect(during, lessThan(tall));
      await tester.pumpAndSettle();
      expect(cardHeight(tester), lessThan(during));
    });

    testWidgets('끝난 뒤에는 더 움직이지 않는다(계속 도는 애니메이션이 없다)', (tester) async {
      final c = await openCard(tester);
      c.text = lines(15);
      await tester.pumpAndSettle(); // 끝나지 않으면 여기서 시간 초과
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('주변 요소', () {
    testWidgets('버튼은 카드가 커져도 오른쪽 위 같은 자리에 있다', (tester) async {
      final c = await openCard(tester, text: '짧은 글');
      Rect chip() => tester.getRect(
        find
            .descendant(
              of: find.byKey(const Key('clear-memo')),
              matching: find.byType(Container),
            )
            .first,
      );
      final before = chip().topLeft - tester.getTopLeft(find.byType(InputCard));
      c.text = lines(25);
      await tester.pumpAndSettle();
      final after = chip().topLeft - tester.getTopLeft(find.byType(InputCard));
      expect(after.dx, closeTo(before.dx, 0.5));
      expect(after.dy, closeTo(before.dy, 0.5));
    });

    testWidgets('글자가 버튼 아래로 파고들지 않는다(오른쪽 여백 유지)', (tester) async {
      final c = await openCard(tester);
      c.text = '매우 긴 글입니다 ' * 60;
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final padding = field.decoration!.contentPadding! as EdgeInsets;
      expect(padding.right, greaterThanOrEqualTo(34 + 12)); // 버튼 폭 + 안쪽 여백
    });

    testWidgets('좁은 화면에서 긴 글도 넘침 오류가 없다', (tester) async {
      final c = await openCard(tester, width: 320);
      c.text = '${lines(30)}\n${'아주 긴 줄입니다 ' * 20}';
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('긴 글에서도 카드가 화면 폭을 넘지 않는다', (tester) async {
      final c = await openCard(tester);
      c.text = '가나다라마바사 ' * 100;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(InputCard)).width,
        lessThanOrEqualTo(380),
      );
    });

    testWidgets('긴 글에서 ✕·✨·🕒가 모두 카드 안에 있다', (tester) async {
      final c = await openCard(tester);
      c.text = lines(25);
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(InputCard));
      for (final k in ['clear-memo', 'card-analyze', 'card-schedule']) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(card.contains(r.center), isTrue, reason: k);
      }
    });
  });
}
