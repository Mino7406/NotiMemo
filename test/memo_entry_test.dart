import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:notimemo/models/memo_entry.dart';
import 'package:notimemo/storage/memo_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MemoEntry.fromJson 마이그레이션', () {
    test('초기 포맷(문자열)', () {
      final e = MemoEntry.fromJson('우유 사기', fallbackId: 'legacy_0');
      expect(e.id, 'legacy_0');
      expect(e.memo, '우유 사기');
      expect(e.time, 0);
      expect(e.priority, MemoPriority.normal);
      expect(e.category, isNull);
      expect(e.scheduledAt, isNull);
    });

    test('v2 포맷({memo,time})', () {
      final e = MemoEntry.fromJson({
        'memo': '숙제',
        'time': 1700000000000,
      }, fallbackId: 'legacy_3');
      expect(e.id, 'legacy_3');
      expect(e.time, 1700000000000);
    });

    test('v3 전체 필드는 왕복해도 같다', () {
      const original = MemoEntry(
        id: 'a1',
        memo: '준비물',
        time: 5,
        category: '학교',
        priority: MemoPriority.high,
        summary: '준비물 챙기기',
        scheduledAt: 99,
      );
      final restored = MemoEntry.fromJson(
        jsonDecode(jsonEncode(original.toJson())),
        fallbackId: 'unused',
      );
      expect(restored.id, 'a1');
      expect(restored.category, '학교');
      expect(restored.priority, MemoPriority.high);
      expect(restored.summary, '준비물 챙기기');
      expect(restored.scheduledAt, 99);
    });

    test('알 수 없는 우선순위 값은 normal', () {
      final e = MemoEntry.fromJson({
        'memo': 'x',
        'time': 1,
        'priority': 'urgent!!',
      }, fallbackId: 'f');
      expect(e.priority, MemoPriority.normal);
    });

    test('기본값인 새 필드는 저장하지 않는다 (옛 앱 호환)', () {
      const e = MemoEntry(id: 'i', memo: 'm', time: 1);
      expect(e.toJson().keys.toSet(), {'id', 'memo', 'time'});
    });
  });

  group('MemoStorage 목록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('옛 포맷 목록을 읽으면 위치 기반의 고정 id를 받는다', () async {
      SharedPreferences.setMockInitialValues({
        'memo_list': jsonEncode([
          '문자열 메모',
          {'memo': '두번째', 'time': 0},
          {'memo': '세번째', 'time': 0},
        ]),
      });
      final first = await MemoStorage.getList();
      final second = await MemoStorage.getList();
      expect(first.map((e) => e.id), ['legacy_0', 'legacy_1', 'legacy_2']);
      expect(second.map((e) => e.id), first.map((e) => e.id));
      expect(first.map((e) => e.memo), ['문자열 메모', '두번째', '세번째']);
    });

    test('저장 후에는 id가 유지된다', () async {
      SharedPreferences.setMockInitialValues({
        'memo_list': jsonEncode(['옛날 메모']),
      });
      final migrated = await MemoStorage.getList();
      final withNew = [MemoEntry.create('새 메모'), ...migrated];
      await MemoStorage.saveList(withNew);

      final reloaded = await MemoStorage.getList();
      expect(reloaded.map((e) => e.id), withNew.map((e) => e.id));
      expect(reloaded.last.memo, '옛날 메모');
    });

    test('빈 저장소는 빈 목록', () async {
      expect(await MemoStorage.getList(), isEmpty);
    });
  });

  group('고정 id 목록', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('네이티브가 기록한 JSON에서 id만 읽는다', () async {
      SharedPreferences.setMockInitialValues({
        'pinned_notes': jsonEncode([
          {'id': 'a', 'memo': '하나', 'time': 1},
          {'id': 'b', 'memo': '둘', 'time': 2},
        ]),
      });
      expect(await MemoStorage.getPinnedIds(), {'a', 'b'});
    });

    test('없거나 깨진 값은 빈 집합', () async {
      expect(await MemoStorage.getPinnedIds(), isEmpty);
      expect(MemoStorage.parsePinnedIds('not json'), isEmpty);
    });
  });
}
