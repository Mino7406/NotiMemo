import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/scheduled_note.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ScheduledNote.parseList', () {
    test('시각이 빠른 순으로 정렬한다', () {
      final raw = jsonEncode([
        {'id': 'b', 'memo': '나중', 'at': 200},
        {'id': 'a', 'memo': '먼저', 'at': 100},
      ]);
      final list = ScheduledNote.parseList(raw);
      expect(list.map((e) => e.id), ['a', 'b']);
      expect(list.first.memo, '먼저');
      expect(list.first.at, 100);
    });

    test('없거나 깨진 값은 빈 목록', () {
      expect(ScheduledNote.parseList(null), isEmpty);
      expect(ScheduledNote.parseList('not json'), isEmpty);
      expect(ScheduledNote.parseList(jsonEncode([{'id': 'x'}])), isEmpty);
    });
  });

  test('MemoStorage.getScheduled는 네이티브가 기록한 값을 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      'scheduled_notes': jsonEncode([
        {'id': 'a', 'memo': '예약', 'at': 5},
      ]),
    });
    final list = await MemoStorage.getScheduled();
    expect(list.single.memo, '예약');
  });
}
