import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/widgets/app_dialogs.dart';
import 'package:notimemo/widgets/app_toast.dart';
import 'package:notimemo/widgets/notice_button.dart';

/// 안내 창·토스트의 모든 버튼에는 윤곽선이 있어야 한다(눌러야 할 곳이 눈에 보이게).
Widget host(
  Future<void> Function(BuildContext) open, {
  ThemeMode mode = ThemeMode.light,
}) {
  return MaterialApp(
    themeMode: mode,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
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

Future<void> show(
  WidgetTester tester,
  Future<void> Function(BuildContext) open, {
  ThemeMode mode = ThemeMode.light,
  Size size = const Size(420, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host(open, mode: mode));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

/// 열려 있는 안내 창 안의 버튼들이 모두 윤곽선 버튼인지 확인한다.
void expectOutlinedButtons(WidgetTester tester, List<String> labels) {
  final dialog = find.byType(Dialog);
  expect(dialog, findsOneWidget);
  expect(
    find.descendant(of: dialog, matching: find.byType(TextButton)),
    findsNothing,
  );
  final buttons = find.descendant(
    of: dialog,
    matching: find.byType(OutlinedButton),
  );
  expect(buttons, findsNWidgets(labels.length));
  for (final label in labels) {
    expect(
      find.descendant(of: buttons, matching: find.text(label)),
      findsOneWidget,
      reason: label,
    );
  }
  for (final b in tester.widgetList<OutlinedButton>(buttons)) {
    final side = b.style!.side!.resolve({});
    expect(side!.width, greaterThan(0));
    expect(side.color.a, greaterThan(0.3)); // 거의 투명한 윤곽선이 아니다
  }
}

/// 안내 창의 버튼은 오른쪽 정렬이다: 가장 오른쪽 버튼이 창 안쪽 여백(24)에 붙고,
/// 버튼이 둘 이상이면 첫 버튼이 왼쪽 가장자리에 붙어 있지 않다.
void expectRightAligned(WidgetTester tester, List<String> labels) {
  // Dialog 위젯의 영역에는 화면 가장자리 여백이 섞여 있어서, 실제 창 카드(Material)를 잰다.
  final dialog = tester.getRect(
    find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first,
  );
  final rects = [
    for (final l in labels)
      tester.getRect(find.widgetWithText(OutlinedButton, l)),
  ];
  final rightMost = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
  expect(
    dialog.right - rightMost,
    closeTo(24, 1.0),
    reason: '가장 오른쪽 버튼이 오른쪽 여백에 붙어야 한다',
  );
  // 한 줄에 다 들어가는 경우: 첫 버튼의 왼쪽 끝 = 오른쪽 끝에서 (버튼 폭 합 + 간격 8)을 뺀 위치.
  // 왼쪽 정렬이었다면 24에 붙어 이 값과 달라진다. 버튼이 창을 꽉 채우는 경우에도 성립한다.
  final sameRow = rects.every(
    (r) => (r.center.dy - rects.first.center.dy).abs() < 2,
  );
  if (sameRow) {
    final totalWidth =
        rects.fold<double>(0, (sum, r) => sum + r.width) +
        8 * (rects.length - 1);
    final first = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
    expect(
      first,
      closeTo(rightMost - totalWidth, 1.5),
      reason: '버튼 줄이 오른쪽 정렬이어야 한다',
    );
  }
}

void main() {
  group('안내 창(다이얼로그) 버튼', () {
    testWidgets('업데이트 알림', (tester) async {
      await show(tester, (c) async => showUpdateDialog(c, '3.0.0'));
      expectOutlinedButtons(tester, ['나중에', '업데이트']);
      expectRightAligned(tester, ['나중에', '업데이트']);
    });

    testWidgets('AI 동의', (tester) async {
      await show(tester, (c) async => showAiConsentDialog(c));
      expectOutlinedButtons(tester, ['AI 없이 사용', '동의하고 사용']);
      expectRightAligned(tester, ['AI 없이 사용', '동의하고 사용']);
    });

    testWidgets('알림 재생성 선택(버튼 3개)', (tester) async {
      await show(tester, (c) async => showRestoreConfirmDialog(c, '치과 예약'));
      expectOutlinedButtons(tester, ['취소', '예약해서 고정', '바로 고정']);
      expectRightAligned(tester, ['취소', '예약해서 고정', '바로 고정']);
    });

    testWidgets('알림 내역 전체삭제 확인', (tester) async {
      await show(tester, (c) async => showClearAllDialog(c, count: 3));
      expectOutlinedButtons(tester, ['취소', '삭제']);
      expectRightAligned(tester, ['취소', '삭제']);
    });

    testWidgets('예약 목록 전체삭제 확인', (tester) async {
      await show(
        tester,
        (c) async =>
            showClearAllDialog(c, count: 3, target: ClearTarget.scheduled),
      );
      expectOutlinedButtons(tester, ['취소', '삭제']);
      expectRightAligned(tester, ['취소', '삭제']);
    });

    testWidgets('새 메모 지우기 확인', (tester) async {
      await show(tester, (c) async => showClearMemoDialog(c, '메모'));
      expectOutlinedButtons(tester, ['취소', '지우기']);
      expectRightAligned(tester, ['취소', '지우기']);
    });

    testWidgets('알림 여유 시간 입력', (tester) async {
      await show(
        tester,
        (c) async => showLeadTimeDialog(c, initial: 30, max: 1440),
      );
      expectOutlinedButtons(tester, ['취소', '확인']);
      expectRightAligned(tester, ['취소', '확인']);
    });

    testWidgets('다크 모드에서도 윤곽선이 있다', (tester) async {
      await show(
        tester,
        (c) async => showClearMemoDialog(c, '메모'),
        mode: ThemeMode.dark,
      );
      expectOutlinedButtons(tester, ['취소', '지우기']);
      expectRightAligned(tester, ['취소', '지우기']);
    });
  });

  group('좁은 화면에서도 넘치지 않는다(버튼이 다음 줄로 내려간다)', () {
    for (final width in [320.0, 360.0, 411.0]) {
      testWidgets('알림 재생성 선택(가로 ${width.toInt()})', (tester) async {
        await show(
          tester,
          (c) async => showRestoreConfirmDialog(c, '치과 예약'),
          size: Size(width, 800),
        );
        expect(tester.takeException(), isNull); // RenderFlex overflow 같은 오류가 없다
        for (final label in ['취소', '예약해서 고정', '바로 고정']) {
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0), reason: label);
          expect(rect.right, lessThanOrEqualTo(width), reason: label);
        }
      });
    }
  });

  group('NoticeButton', () {
    testWidgets('색이 없으면 회색 윤곽선, 있으면 그 색의 윤곽선과 옅은 배경', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                NoticeButton(
                  key: const Key('plain'),
                  label: '취소',
                  onPressed: () {},
                ),
                NoticeButton(
                  key: const Key('accent'),
                  label: '확인',
                  color: Colors.red,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final plain = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('plain')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final accent = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const Key('accent')),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(
        plain.style!.backgroundColor?.resolve({}),
        isNull,
      ); // 강조 없는 버튼은 배경이 없다
      expect(accent.style!.backgroundColor!.resolve({}), isNotNull);
      expect(
        accent.style!.side!.resolve({})!.color.r,
        greaterThan(0.8),
      ); // 빨강 계열
      expect(plain.style!.side!.resolve({})!.width, greaterThan(0));
    });

    testWidgets('눌러서 동작하고, 터치 높이가 40 이상이다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NoticeButton(label: '확인', onPressed: () => taps++),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(40),
      );
      await tester.tap(find.text('확인'));
      expect(taps, 1);
    });
  });

  group('토스트의 동작 버튼', () {
    testWidgets('되돌리기는 흰 윤곽선 버튼이고 누르면 동작하며 토스트가 닫힌다', (tester) async {
      var undone = 0;
      await show(tester, (c) async {
        showAppToast(c, '바꿨어요', actionLabel: '되돌리기', onAction: () => undone++);
      });
      final button = find.byKey(const Key('toast-action'));
      expect(button, findsOneWidget);
      expect(find.byType(SnackBarAction), findsNothing);
      final side = tester
          .widget<OutlinedButton>(button)
          .style!
          .side!
          .resolve({});
      expect(side!.color, Colors.white);
      expect(side.width, greaterThan(0));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('바꿨어요'), findsNothing);
    });

    testWidgets('동작이 없는 토스트에는 버튼이 없다', (tester) async {
      await show(tester, (c) async {
        showAppToast(c, '그냥 안내');
      });
      expect(find.byKey(const Key('toast-action')), findsNothing);
      expect(find.text('그냥 안내'), findsOneWidget);
    });

    testWidgets('긴 글에서도 넘치지 않는다', (tester) async {
      await show(tester, (c) async {
        showAppToast(
          c,
          '아주 긴 안내 문구입니다. ' * 4,
          actionLabel: '되돌리기',
          onAction: () {},
        );
      }, size: const Size(320, 800));
      expect(tester.takeException(), isNull);
    });

    testWidgets('동작 버튼이 있는 토스트와 없는 토스트의 크기가 같다', (tester) async {
      Future<Size> measure(Future<void> Function(BuildContext) open) async {
        await tester.pumpWidget(const SizedBox()); // 이전 토스트 정리
        await show(tester, open);
        return tester.getSize(find.byType(SnackBar));
      }

      final plain = await measure((c) async => showAppToast(c, '그냥 안내'));
      final withAction = await measure(
        (c) async =>
            showAppToast(c, '바꿨어요', actionLabel: '되돌리기', onAction: () {}),
      );
      final error = await measure(
        (c) async => showAppToast(c, '오류 안내', isError: true),
      );
      expect(withAction.height, closeTo(plain.height, 0.5));
      expect(withAction.width, closeTo(plain.width, 0.5));
      expect(error.height, closeTo(plain.height, 0.5));
    });

    testWidgets('동작 버튼 높이는 토스트 내용 줄 높이와 같다', (tester) async {
      await show(tester, (c) async {
        showAppToast(c, '바꿨어요', actionLabel: '되돌리기', onAction: () {});
      });
      final button = tester.getSize(find.byKey(const Key('toast-action')));
      expect(button.height, toastContentHeight);
    });

    testWidgets('두 줄이 되는 긴 글은 토스트가 그만큼만 커진다', (tester) async {
      await show(
        tester,
        (c) async => showAppToast(c, '짧은 글'),
        size: const Size(320, 800),
      );
      final one = tester.getSize(find.byType(SnackBar)).height;
      await tester.pumpWidget(const SizedBox());
      await show(
        tester,
        (c) async => showAppToast(
          c,
          '아주 긴 안내 문구입니다. ' * 4,
          actionLabel: '되돌리기',
          onAction: () {},
        ),
        size: const Size(320, 800),
      );
      final many = tester.getSize(find.byType(SnackBar)).height;
      expect(many, greaterThan(one)); // 긴 글은 커지되
      expect(tester.takeException(), isNull); // 넘치지 않는다
    });

    testWidgets('컨트롤러로 닫을 수 있다', (tester) async {
      ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? toast;
      await show(tester, (c) async {
        toast = showAppToast(c, '곧 닫힘');
      });
      expect(find.text('곧 닫힘'), findsOneWidget);
      toast!.close();
      await tester.pumpAndSettle();
      expect(find.text('곧 닫힘'), findsNothing);
    });
  });
}
