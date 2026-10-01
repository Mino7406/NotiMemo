import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 자동 정리에 관한 설정과 사용량 저장소.
class AiStorage {
  static const _keyConsent = 'ai_consent';
  static const _keyDeviceId = 'ai_device_id';
  static const _keyUsageDate = 'ai_usage_date';
  static const _keyUsageCount = 'ai_usage_count';

  /// 동의 여부. null = 아직 묻지 않음, true = 동의(켬), false = 거부(끔).
  static Future<bool?> getConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyConsent);
  }

  static Future<void> setConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConsent, value);
  }

  /// 설치별 무작위 id. 서버가 기기별 횟수 제한을 거는 데만 쓰고, 안드로이드 고유 번호는 쓰지 않는다.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      final rng = Random.secure();
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      id = List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘(현지 날짜) 서버를 부른 횟수. 날짜가 바뀌면 0.
  static Future<int> usageToday(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyUsageDate) != _dateKey(now)) return 0;
    return prefs.getInt(_keyUsageCount) ?? 0;
  }

  static Future<void> addUsage(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(now);
    final count = prefs.getString(_keyUsageDate) == today
        ? (prefs.getInt(_keyUsageCount) ?? 0)
        : 0;
    await prefs.setString(_keyUsageDate, today);
    await prefs.setInt(_keyUsageCount, count + 1);
  }
}
