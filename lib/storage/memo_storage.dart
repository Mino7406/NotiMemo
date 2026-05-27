import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MemoStorage {
  static const _keyList = 'memo_list';
  static const _keyCurrent = 'saved_memo';

  static Future<List<String>> getList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyList);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<String>();
  }

  static Future<void> saveList(List<String> memos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyList, jsonEncode(memos));
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
}
