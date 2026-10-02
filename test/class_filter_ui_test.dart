import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:notimemo/widgets/history_sheet.dart';
import 'package:notimemo/widgets/scheduled_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<MemoEntry> sample() => const [
  MemoEntry(
    id: 'a',
    memo: '수학 숙제',
    time: 1,
    category: '학교',
    priority: MemoPriority.high,
  ),
  MemoEntry(id: 'b', memo: '영어 단어', time: 2, category: '학교'),
  MemoEntry(id: 'c', memo: '우유 사기', time: 3, category: '쇼핑'),
  MemoEntry(
    id: 'd',
    memo: '병원 가기',
    time: 4,
    category: '건강',
    priority: MemoPriority.low,
  ),
  MemoEntry(id: 'e', memo: '미분류 메모', time: 5),
];

/// 열린 알림 내역에서 일어난 일을 기록한다.
class Calls {
  final deleted = <int>[];
  final restored = <String>[];
  var cleared = 0;
}

Widget historyHost(List<MemoEntry> list, Calls calls) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: ElevatedButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => HistorySheet(
            memoList: list,
            onDelete: (i) async => calls.deleted.add(i),
            onClearAll: () async => calls.cleared++,
            onRestore: (e) async => calls.restored.add(e.id),
          ),
        ),
        child: const Text('열기'),
      ),
    ),
  ),
);

Future<Calls> openHistory(WidgetTester tester, [List<MemoEntry>? list]) async {
  await tester.binding.setSurfaceSize(const Size(420, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final calls = Calls();
  await tester.pumpWidget(historyHost(list ?? sample(), calls));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return calls;
}

Future<void> tapChip(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// 항목(메모 글자)이 들어 있는 줄에서 ✕(삭제) 버튼을 찾는다.
Finder closeOf(String memo) => find.descendant(
  of: find.ancestor(of: find.text(memo), matching: find.byType(Dismissible)),
  matching: find.byIcon(Icons.close_rounded),
);

void main() {
  group('알림 내역 필터', () {
    testWidgets('있는 분류만 정해진 순서로, 개수와 함께 칩이 나온다', (tester) async {
      await openHistory(tester);
      expect(find.text('전체 5'), findsOneWidget);
      expect(find.text('학교 2'), findsOneWidget);
      expect(find.text('쇼핑 1'), findsOneWidget);
      expect(find.text('건강 1'), findsOneWidget);
      expect(find.byKey(const Key('filter-cat-할일')), findsNothing);
      expect(find.byKey(const Key('filter-cat-돈')), findsNothing);
      // 순서: 학교 → 쇼핑 → 건강
      final x = [
        for (final k in ['학교', '쇼핑', '건강'])
          tester.getTopLeft(find.byKey(Key('filter-cat-$k'))).dx,
      ];
      expect(x[0] < x[1] && x[1] < x[2], isTrue);
    });

    testWidgets('우선순위 칩은 있는 것만(높음→보통→낮음)', (tester) async {
      await openHistory(tester);
      expect(find.text('높음 1'), findsOneWidget);
      expect(find.text('보통 3'), findsOneWidget);
      expect(find.text('낮음 1'), findsOneWidget);
    });

    testWidgets('분류를 누르면 그 분류만 보인다', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-cat-학교');
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.text('영어 단어'), findsOneWidget);
      expect(find.text('우유 사기'), findsNothing);
      expect(find.text('병원 가기'), findsNothing);
      expect(find.text('미분류 메모'), findsNothing);
    });

    testWidgets('분류 + 우선순위는 둘 다 만족하는 것만', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-cat-학교');
      await tapChip(tester, 'filter-pri-high');
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.text('영어 단어'), findsNothing);
    });

    testWidgets('우선순위만 고르면 분류 없는 메모도 포함된다', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-pri-normal');
      expect(find.text('영어 단어'), findsOneWidget);
      expect(find.text('우유 사기'), findsOneWidget);
      expect(find.text('미분류 메모'), findsOneWidget);
      expect(find.text('수학 숙제'), findsNothing);
    });

    testWidgets('결과가 없으면 안내와 필터 해제 버튼이 나온다', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-cat-쇼핑');
      await tapChip(tester, 'filter-pri-high');
      expect(find.byKey(const Key('history-filter-empty')), findsOneWidget);
      expect(find.text('조건에 맞는 메모가 없어요'), findsOneWidget);
      await tester.tap(find.text('필터 해제'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history-filter-empty')), findsNothing);
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.text('영어 단어'), findsOneWidget); // 필터가 풀려 다시 보임
    });

    testWidgets('전체 칩으로 되돌린다', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-cat-건강');
      expect(find.text('수학 숙제'), findsNothing);
      await tapChip(tester, 'filter-cat-all');
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('필터를 건 채 삭제해도 원래 목록의 올바른 위치가 지워진다', (tester) async {
      final calls = await openHistory(tester);
      await tapChip(tester, 'filter-cat-쇼핑'); // 원래 위치 2
      await tester.tap(closeOf('우유 사기'));
      await tester.pumpAndSettle();
      expect(calls.deleted, [2]);
    });

    testWidgets('필터를 건 채 ↻를 눌러 재생성하면 그 항목이 전달된다', (tester) async {
      final calls = await openHistory(tester);
      await tapChip(tester, 'filter-cat-건강');
      await tester.tap(find.byKey(const Key('history-restore-d')));
      await tester.pumpAndSettle();
      expect(calls.restored, ['d']);
    });

    testWidgets('마지막 남은 분류를 지우면 필터가 풀려 갇히지 않는다', (tester) async {
      await openHistory(tester);
      await tapChip(tester, 'filter-cat-건강');
      await tester.tap(closeOf('병원 가기'));
      await tester.pumpAndSettle();
      // 건강 항목이 없어졌으니 조건이 풀리고 나머지가 다시 보인다.
      expect(find.byKey(const Key('history-filter-empty')), findsNothing);
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.byKey(const Key('filter-cat-건강')), findsNothing);
    });

    testWidgets('항목이 1개뿐이면 필터 줄이 없다', (tester) async {
      await openHistory(tester, [sample().first]);
      expect(find.byKey(const Key('filter-cat-all')), findsNothing);
    });

    testWidgets('분류된 항목이 하나도 없으면 필터 줄이 없다', (tester) async {
      await openHistory(tester, const [
        MemoEntry(id: 'x', memo: '하나', time: 1),
        MemoEntry(id: 'y', memo: '둘', time: 2),
      ]);
      expect(find.byKey(const Key('filter-cat-all')), findsNothing);
      expect(find.text('하나'), findsOneWidget);
    });

    testWidgets('전체삭제 확인 창: 필터가 없으면 안내 문구가 없다', (tester) async {
      await openHistory(tester);
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      expect(find.textContaining('필터와 상관없이'), findsNothing);
      expect(find.textContaining('5개'), findsOneWidget);
    });

    testWidgets('전체삭제 확인 창: 필터를 건 상태면 전체가 지워진다고 알린다', (tester) async {
      final calls = await openHistory(tester);
      await tapChip(tester, 'filter-cat-학교');
      await tester.tap(find.byKey(const Key('history-clear-all')));
      await tester.pumpAndSettle();
      expect(find.textContaining('5개'), findsOneWidget); // 보이는 2개가 아니라 전체 5개
      expect(find.textContaining('필터와 상관없이 전체가 삭제돼요'), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(calls.cleared, 1);
    });
  });

  group('예약 목록 필터', () {
    const channel = MethodChannel('com.example.notimemo/notification');
    final cancelled = <String>[];

    setUp(() {
      cancelled.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelSchedule') {
              cancelled.add((call.arguments as Map)['id'] as String);
            }
            return null;
          });
    });

    Future<void> openScheduled(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      await MemoStorage.saveList(sample());
      final at = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'scheduled_notes',
        jsonEncode([
          for (final e in sample())
            {'id': e.id, 'memo': e.memo, 'at': at + e.time},
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showScheduledSheet(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    testWidgets('알림 내역과 같은 칩이 나오고 분류로 걸러진다', (tester) async {
      await openScheduled(tester);
      expect(find.text('전체 5'), findsOneWidget);
      expect(find.text('학교 2'), findsOneWidget);
      await tapChip(tester, 'filter-cat-쇼핑');
      expect(find.text('우유 사기'), findsOneWidget);
      expect(find.text('수학 숙제'), findsNothing);
      await tapChip(tester, 'filter-cat-all');
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('분류 + 우선순위, 결과 없음 안내, 필터 해제', (tester) async {
      await openScheduled(tester);
      await tapChip(tester, 'filter-cat-학교');
      await tapChip(tester, 'filter-pri-high');
      expect(find.text('수학 숙제'), findsOneWidget);
      expect(find.text('영어 단어'), findsNothing);
      await tapChip(tester, 'filter-cat-건강'); // 건강 + 높음 = 없음
      expect(find.byKey(const Key('scheduled-filter-empty')), findsOneWidget);
      await tester.tap(find.text('필터 해제'));
      await tester.pumpAndSettle();
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('필터를 건 채 예약을 취소하면 그 예약만 취소된다', (tester) async {
      await openScheduled(tester);
      await tapChip(tester, 'filter-cat-쇼핑');
      await tester.tap(find.byTooltip('예약 취소'));
      await tester.pumpAndSettle();
      expect(cancelled, ['c']);
    });
  });
}
