import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memo_entry.dart';

class MemoStorage {
  static const _keyList = 'memo_list';
  static const _keyCurrent = 'saved_memo';
  static const _keyActive = 'notification_active';

  static Future<List<MemoEntry>> getList() async {
    final prefs = await SharedPreferences.getInstance();
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
    await prefs.setString(_keyList, jsonEncode(entries.map((e) => e.toJson()).toList()));
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

  static Future<bool> isNotificationActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(_keyActive) ?? false;
  }

  static Future<void> setNotificationActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    if (active) {
      await prefs.setBool(_keyActive, true);
    } else {
      await prefs.remove(_keyActive);
    }
  }
}
