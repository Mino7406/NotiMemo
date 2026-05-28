import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MemoEntry {
  final String memo;
  final int time; // ms since epoch, 0 = unknown (migrated from old format)

  const MemoEntry({required this.memo, required this.time});

  Map<String, dynamic> toJson() => {'memo': memo, 'time': time};

  factory MemoEntry.fromJson(dynamic json) {
    if (json is String) return MemoEntry(memo: json, time: 0);
    return MemoEntry(
      memo: json['memo'] as String,
      time: (json['time'] as num).toInt(),
    );
  }
}

class MemoStorage {
  static const _keyList = 'memo_list';
  static const _keyCurrent = 'saved_memo';
  static const _keyActive = 'notification_active';

  static Future<List<MemoEntry>> getList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyList);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map(MemoEntry.fromJson).toList();
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
