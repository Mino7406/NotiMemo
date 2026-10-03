import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/theme/app_theme.dart';
import 'package:notimemo/widgets/history_sheet.dart';
import 'package:notimemo/widgets/home_widgets.dart';

/// 팀원 사용 후기 반영 테스트: 전체삭제 확인, 윤곽선·큰 버튼.
List<MemoEntry> entries() => [
  const MemoEntry(id: 'a', memo: '수학 숙제', time: 1),
  const MemoEntry(id: 'b', memo: '우유 사기', time: 2),
  const MemoEntry(id: 'c', memo: '치과 예약', time: 3),
];

Widget historyHost({
  required List<MemoEntry> list,
  required Future<void> Function() onClearAll,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => HistorySheet(
                memoList: list,
                onDelete: (_) async {},
                onClearAll: onClearAll,
                onRestore: (_) async {},
              ),
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
}

Future<void> openHistory(
  WidgetTester tester, {
  required Future<void> Function() onClearAll,
}) async {
  await tester.pumpWidget(historyHost(list: entries(), onClearAll: onClearAll));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  group('알림 내역 전체삭제', () {
    testWidgets('누르면 바로 지우지 않고 확인 창이 뜬다', (tester) async {
      var cleared = 0;
      await openHistory(tester, onClearAll: () async => cleared++);
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('전체 삭제'), findsOneWidget);
      expect(
        find.text('현재 기록된 내역 3개를 전부 삭제하시겠습니까?\n삭제한 내역은 되돌릴 수 없어요.'),
        findsOneWidget,
      );
      expect(cleared, 0);
      expect(find.text('수학 숙제'), findsOneWidget); // 아직 그대로
    });

    testWidgets('취소하면 아무것도 지워지지 않는다', (tester) async {
      var cleared = 0;
      await openHistory(tester, onClearAll: () async => cleared++);
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(cleared, 0);
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.text('우유 사기'), findsOneWidget);
      expect(find.text('치과 예약'), findsOneWidget);
    });

    testWidgets('확인 창 바깥을 눌러 닫아도 지워지지 않는다', (tester) async {
      var cleared = 0;
      await openHistory(tester, onClearAll: () async => cleared++);
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(cleared, 0);
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('삭제를 누르면 한 번만 지우고 목록이 비워진다', (tester) async {
      var cleared = 0;
      await openHistory(tester, onClearAll: () async => cleared++);
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(cleared, 1);
      expect(find.text('수학 숙제'), findsNothing);
      expect(find.text('저장된 메모가 없어요'), findsOneWidget);
      // 비어 있으면 전체삭제 버튼도 사라진다.
      expect(find.byKey(const Key('history-clear-all')), findsNothing);
    });

    testWidgets('전체삭제 버튼에는 윤곽선이 있다', (tester) async {
      await openHistory(tester, onClearAll: () async {});
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('history-clear-all')),
      );
      final side = button.style!.side!.resolve({});
      expect(side, isNotNull);
      expect(side!.width, greaterThan(0));
      expect(side.color.a, greaterThan(0));
    });
  });

  group('☰ 메뉴 버튼', () {
    Widget topBar() => MaterialApp(
      home: Scaffold(
        endDrawer: const Drawer(),
        body: Builder(
          builder: (context) =>
              TopBar(textColor: Colors.black, subColor: Colors.grey),
        ),
      ),
    );

    testWidgets('터치 영역이 48dp 이상이다', (tester) async {
      await tester.pumpWidget(topBar());
      final size = tester.getSize(find.byKey(const Key('menu-button')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('윤곽선이 있다', (tester) async {
      await tester.pumpWidget(topBar());
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('menu-button')),
          matching: find.byType(Container),
        ),
      );
      final deco = box.decoration! as BoxDecoration;
      expect(deco.border, isNotNull);
      expect((deco.border! as Border).top.width, greaterThan(0));
      expect((deco.border! as Border).top.color, AppColors.borderLight);
    });

    testWidgets('아이콘이 이전보다 크다', (tester) async {
      await tester.pumpWidget(topBar());
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('menu-button')),
          matching: find.byIcon(Icons.menu_rounded),
        ),
      );
      expect(icon.size, greaterThan(22));
    });

    testWidgets('눌러서 메뉴를 열 수 있다', (tester) async {
      await tester.pumpWidget(topBar());
      await tester.tap(find.byKey(const Key('menu-button')));
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsOneWidget);
    });
  });
}
