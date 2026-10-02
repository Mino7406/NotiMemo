import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo_entry.dart';
import '../models/scheduled_note.dart';
import '../services/notification_service.dart';

class MemoStorage {
  static const _keyList = 'memo_list';
  static const _keyCurrent = 'saved_memo';
  static const _keyPinned = 'pinned_notes';
  static const _keyScheduled = 'scheduled_notes';

  static Future<List<MemoEntry>> getList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 알림에서 고친 내용을 네이티브가 기록하므로
    final raw = prefs.getString(_keyList);
    if (raw == null) return [];
    final items = jsonDecode(raw) as List;
    return [
      for (var i = 0; i < items.length; i++)
        MemoEntry.fromJson(items[i], fallbackId: 'legacy_$i'),
    ];
  }

  static Future<void> saveList(List<MemoEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyList,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
    await NotificationService.refreshWidget();
  }

  static Future<String?> getCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrent);
  }

  static Future<void> setCurrent(String memo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrent, memo);
  }

  static Future<void> clearCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrent);
  }

  /// 지금 알림창에 고정 중인 메모의 id들. 네이티브 서비스가 기록하는 값이라
  /// 읽기 전에 캐시를 새로 고친다.
  static Future<Set<String>> getPinnedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return parsePinnedIds(prefs.getString(_keyPinned));
  }

  /// 예약된 메모 (시각 순). 네이티브가 기록하는 값이라 캐시를 새로 고친다.
  static Future<List<ScheduledNote>> getScheduled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return ScheduledNote.parseList(prefs.getString(_keyScheduled));
  }

  static Set<String> parsePinnedIds(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final o in jsonDecode(raw) as List) (o as Map)['id'] as String,
      };
    } catch (_) {
      return {};
    }
  }
}
