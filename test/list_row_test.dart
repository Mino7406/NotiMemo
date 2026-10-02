import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:notimemo/widgets/history_sheet.dart';
import 'package:notimemo/widgets/memo_list_row.dart';
import 'package:notimemo/widgets/scheduled_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget rowHost({
  String? label,
  String memo = '3시 병원',
  int? maxLines,
  String? time = '오후 1:58',
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 320,
          child: MemoListRow(
            icon: Icons.push_pin_rounded,
            label: label,
            labelKey: const Key('row-label'),
            memo: memo,
            memoMaxLines: maxLines,
            timeText: time,
            textColor: Colors.black,
            subColor: Colors.grey,
            actions: const [SizedBox(width: 36, height: 36)],
          ),
        ),
      ),
    ),
  );
}

/// 메모 글자 첫 줄의 세로 중심.
double firstLineCenter(WidgetTester tester, String memo) {
  final rect = tester.getRect(find.text(memo));
  return rect.top + (MemoListRow.memoFontSize * MemoListRow.memoLineHeight) / 2;
}

void main() {
  group('MemoListRow 줄맞춤', () {
    testWidgets('아이콘이 메모 글줄과 같은 높이에 있다(분류 줄이 있어도)', (tester) async {
      await tester.pumpWidget(rowHost(label: '건강 · 우선순위 높음'));
      final icon = tester.getCenter(find.byIcon(Icons.push_pin_rounded));
      expect(icon.dy, closeTo(firstLineCenter(tester, '3시 병원'), 0.6));
    });

    testWidgets('분류 줄이 없어도 아이콘은 메모 글줄과 같은 높이', (tester) async {
      await tester.pumpWidget(rowHost(label: null));
      final icon = tester.getCenter(find.byIcon(Icons.push_pin_rounded));
      expect(icon.dy, closeTo(firstLineCenter(tester, '3시 병원'), 0.6));
    });

    testWidgets('메모가 두 줄이어도 아이콘은 첫 줄 높이', (tester) async {
      final long = '가나다라마바사아자차카타파하 ' * 6;
      await tester.pumpWidget(
        rowHost(label: '학교 · 우선순위 보통', memo: long.trim(), maxLines: 2),
      );
      final memoRect = tester.getRect(find.text(long.trim()));
      expect(memoRect.height, greaterThan(30)); // 실제로 두 줄이다
      final icon = tester.getCenter(find.byIcon(Icons.push_pin_rounded));
      expect(icon.dy, closeTo(firstLineCenter(tester, long.trim()), 0.6));
    });

    testWidgets('분류 줄·메모·시간 줄의 왼쪽 선이 같다', (tester) async {
      await tester.pumpWidget(rowHost(label: '건강 · 우선순위 높음'));
      final memoLeft = tester.getTopLeft(find.text('3시 병원')).dx;
      final labelLeft = tester
          .getTopLeft(find.byKey(const Key('row-label')))
          .dx;
      final timeLeft = tester.getTopLeft(find.text('오후 1:58')).dx;
      expect(labelLeft, closeTo(memoLeft, 0.1));
      expect(timeLeft, closeTo(memoLeft, 0.1));
    });

    testWidgets('아이콘은 글자보다 왼쪽에 있고 사이 간격이 일정하다', (tester) async {
      await tester.pumpWidget(rowHost(label: '건강 · 우선순위 높음'));
      final iconRect = tester.getRect(find.byIcon(Icons.push_pin_rounded));
      final memoLeft = tester.getTopLeft(find.text('3시 병원')).dx;
      expect(iconRect.right, lessThanOrEqualTo(memoLeft));
      // 아이콘 칸(15) + 간격(10) = 들여쓰기 25
      expect(
        memoLeft - tester.getTopLeft(find.byType(MemoListRow)).dx,
        closeTo(MemoListRow.indent, 0.1),
      );
    });

    testWidgets('시간 줄이 없을 수도 있다', (tester) async {
      await tester.pumpWidget(rowHost(label: '학교 · 우선순위 보통', time: null));
      expect(find.text('오후 1:58'), findsNothing);
      final icon = tester.getCenter(find.byIcon(Icons.push_pin_rounded));
      expect(icon.dy, closeTo(firstLineCenter(tester, '3시 병원'), 0.6));
    });
  });

  group('OutlinedIconAction', () {
    testWidgets('윤곽선이 있고 누르면 동작하며 툴팁이 있다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OutlinedIconAction(
                key: const Key('btn'),
                icon: Icons.close_rounded,
                tooltip: '삭제',
                isDark: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('btn')),
          matching: find.byType(Container),
        ),
      );
      final border = (box.decoration! as BoxDecoration).border! as Border;
      expect(border.top.width, greaterThan(0));
      expect(border.top.color.a, greaterThan(0));
      expect(tester.getSize(find.byKey(const Key('btn'))), const Size(36, 36));
      await tester.tap(find.byKey(const Key('btn')));
      expect(taps, 1);
      expect(find.byTooltip('삭제'), findsOneWidget);
    });

    testWidgets('윤곽선 색은 라이트/다크에서 배경과 구분된다', (tester) async {
      expect(outlineColor(false), isNot(const Color(0xFFFFFFFF)));
      expect(outlineColor(true), isNot(const Color(0xFF161721)));
      expect(outlineColor(false), isNot(outlineColor(true)));
    });
  });

  group('알림 내역 항목 버튼', () {
    List<MemoEntry> items() => const [
      MemoEntry(id: 'a', memo: '수학 숙제', time: 1, category: '학교'),
      MemoEntry(id: 'b', memo: '우유 사기', time: 2, category: '쇼핑'),
    ];

    Future<({List<String> restored, List<int> deleted})> open(
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final restored = <String>[];
      final deleted = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => HistorySheet(
                    memoList: items(),
                    onDelete: (i) async => deleted.add(i),
                    onClearAll: () async {},
                    onRestore: (e) async => restored.add(e.id),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return (restored: restored, deleted: deleted);
    }

    testWidgets('항목마다 윤곽선이 있는 다시 고정(↻)·삭제(✕) 버튼이 있다', (tester) async {
      await open(tester);
      for (final id in ['a', 'b']) {
        expect(find.byKey(Key('history-restore-$id')), findsOneWidget);
        expect(find.byKey(Key('history-delete-$id')), findsOneWidget);
      }
      expect(find.byTooltip('다시 고정'), findsNWidgets(2));
    });

    testWidgets('↻와 ✕ 사이에 넉넉한 간격이 있다(삭제를 잘못 누르지 않게)', (tester) async {
      await open(tester);
      final restore = tester.getRect(
        find.byKey(const Key('history-restore-a')),
      );
      final delete = tester.getRect(find.byKey(const Key('history-delete-a')));
      expect(delete.left - restore.right, closeTo(MemoListRow.actionGap, 0.1));
      expect(MemoListRow.actionGap, greaterThanOrEqualTo(12));
      // 두 버튼은 같은 높이에 나란히 있다.
      expect(delete.center.dy, closeTo(restore.center.dy, 0.1));
    });

    testWidgets('↻를 누르면 그 항목으로 재생성 흐름이 시작된다', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const Key('history-restore-b')));
      await tester.pumpAndSettle();
      expect(r.restored, ['b']);
    });

    testWidgets('항목 줄(글자·분류·빈 곳)을 눌러도 재생성되지 않는다', (tester) async {
      final r = await open(tester);
      await tester.tap(find.text('수학 숙제'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('history-label-a')));
      await tester.pumpAndSettle();
      // 행의 빈 곳(↻·✕ 버튼에서 떨어진 왼쪽 가장자리)
      final rowRect = tester.getRect(find.byType(MemoListRow).first);
      await tester.tapAt(Offset(rowRect.left + 2, rowRect.center.dy));
      await tester.pumpAndSettle();
      expect(r.restored, isEmpty);
      expect(find.text('수학 숙제'), findsOneWidget); // 시트도 그대로 열려 있다
    });

    testWidgets('✕를 누르면 그 항목만 삭제된다', (tester) async {
      final r = await open(tester);
      await tester.tap(find.byKey(const Key('history-delete-b')));
      await tester.pumpAndSettle();
      expect(r.deleted, [1]);
      expect(find.text('우유 사기'), findsNothing);
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('아이콘과 글줄 정렬이 실제 화면에서도 맞다', (tester) async {
      await open(tester);
      final icon = tester.getCenter(find.byIcon(Icons.push_pin_rounded).first);
      expect(icon.dy, closeTo(firstLineCenter(tester, '수학 숙제'), 0.6));
      final label = tester
          .getTopLeft(find.byKey(const Key('history-label-a')))
          .dx;
      expect(label, closeTo(tester.getTopLeft(find.text('수학 숙제')).dx, 0.1));
    });
  });

  group('예약 목록 전체삭제', () {
    const channel = MethodChannel('com.example.notimemo/notification');
    final cancelled = <String>[];

    setUp(() {
      cancelled.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'cancelSchedule') {
              final id = (call.arguments as Map)['id'] as String;
              cancelled.add(id);
              // 실제 앱에서는 네이티브가 저장된 예약에서 지운다. 그대로 흉내 낸다.
              final prefs = await SharedPreferences.getInstance();
              final raw = prefs.getString('scheduled_notes');
              if (raw != null) {
                final left = [
                  for (final n in jsonDecode(raw) as List)
                    if ((n as Map)['id'] != id) n,
                ];
                await prefs.setString('scheduled_notes', jsonEncode(left));
              }
            }
            return null;
          });
    });

    Future<void> openScheduled(WidgetTester tester, {int count = 3}) async {
      await tester.binding.setSurfaceSize(const Size(420, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({});
      final entries = [
        const MemoEntry(id: 's1', memo: '수학 숙제', time: 1, category: '학교'),
        const MemoEntry(id: 's2', memo: '영어 단어', time: 2, category: '학교'),
        const MemoEntry(id: 's3', memo: '우유 사기', time: 3, category: '쇼핑'),
      ].take(count).toList();
      await MemoStorage.saveList(entries);
      final at = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'scheduled_notes',
        jsonEncode([
          for (final e in entries)
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

    testWidgets('윤곽선 있는 전체삭제 버튼이 있다', (tester) async {
      await openScheduled(tester);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('scheduled-clear-all')),
      );
      final side = button.style!.side!.resolve({});
      expect(side!.width, greaterThan(0));
      expect(find.text('전체삭제'), findsOneWidget);
    });

    testWidgets('누르면 확인 창이 뜬다(예약용 문구)', (tester) async {
      await openScheduled(tester);
      await tester.tap(find.byKey(const Key('scheduled-clear-all')));
      await tester.pumpAndSettle();
      expect(find.text('전체 삭제'), findsOneWidget);
      expect(
        find.text('현재 예약된 알림 3개를 전부 삭제하시겠습니까?\n삭제하면 예약한 시각에 알림이 고정되지 않아요.'),
        findsOneWidget,
      );
      expect(cancelled, isEmpty);
    });

    testWidgets('취소하면 아무 예약도 취소되지 않는다', (tester) async {
      await openScheduled(tester);
      await tester.tap(find.byKey(const Key('scheduled-clear-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(cancelled, isEmpty);
      expect(find.text('수학 숙제'), findsOneWidget);
    });

    testWidgets('바깥을 눌러 닫아도 취소되지 않는다', (tester) async {
      await openScheduled(tester);
      await tester.tap(find.byKey(const Key('scheduled-clear-all')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(cancelled, isEmpty);
    });

    testWidgets('삭제를 누르면 모든 예약이 취소되고 빈 목록이 된다', (tester) async {
      await openScheduled(tester);
      await tester.tap(find.byKey(const Key('scheduled-clear-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(cancelled.toSet(), {'s1', 's2', 's3'});
      expect(cancelled, hasLength(3)); // 중복 없이 한 번씩
      expect(find.text('예약된 메모가 없어요'), findsOneWidget);
      expect(find.byKey(const Key('scheduled-clear-all')), findsNothing);
    });

    testWidgets('필터를 건 채여도 전체가 취소되고, 확인 창이 그렇게 알린다', (tester) async {
      await openScheduled(tester);
      await tester.tap(find.byKey(const Key('filter-cat-쇼핑')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scheduled-clear-all')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3개'), findsOneWidget); // 보이는 1개가 아니라 전체
      expect(find.textContaining('필터와 상관없이 전체가 삭제돼요'), findsOneWidget);
      await tester.tap(find.text('삭제'));
      await tester.pumpAndSettle();
      expect(cancelled.toSet(), {'s1', 's2', 's3'});
    });

    testWidgets('항목의 ✕는 윤곽선이 있고 그 예약만 취소한다', (tester) async {
      await openScheduled(tester);
      expect(find.byKey(const Key('scheduled-cancel-s2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('scheduled-cancel-s2')));
      await tester.pumpAndSettle();
      expect(cancelled, ['s2']);
    });

    testWidgets('예약이 없으면 전체삭제 버튼이 없다', (tester) async {
      await openScheduled(tester, count: 0);
      expect(find.byKey(const Key('scheduled-clear-all')), findsNothing);
      expect(find.text('예약된 메모가 없어요'), findsOneWidget);
    });

    testWidgets('아이콘과 글줄 정렬이 실제 화면에서도 맞다', (tester) async {
      await openScheduled(tester);
      final icon = tester.getCenter(find.byIcon(Icons.schedule_rounded).first);
      expect(icon.dy, closeTo(firstLineCenter(tester, '수학 숙제'), 0.6));
    });
  });
}
