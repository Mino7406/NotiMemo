import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/reminder_time.dart';

/// AI 자동 정리에 관한 설정과 사용량 저장소.
class AiStorage {
  static const _keyConsent = 'ai_consent';
  static const _keyDeviceId = 'ai_device_id';
  static const _keyUsageDate = 'ai_usage_date';
  static const _keyUsageCount = 'ai_usage_count';
  static const _keyLeadMinutes = 'ai_lead_minutes';
  static const _keyAutoClassify = 'ai_auto_classify';

  /// 여유 시간으로 고를 수 있는 최댓값(분). 하루.
  static const maxLeadMinutes = 1440;

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

  /// AI가 제안하는 알림 시각을 일정보다 몇 분 앞당길지. 0이면 일정 시각 그대로.
  static Future<int> getLeadMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_keyLeadMinutes) ?? defaultLeadMinutes).clamp(
      0,
      maxLeadMinutes,
    );
  }

  static Future<void> setLeadMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLeadMinutes, minutes.clamp(0, maxLeadMinutes));
  }

  /// 자동 분류(카테고리·우선순위·요약) 사용 여부. 기본 켜짐. 끄면 ✨은 예약 시각만 찾는다.
  static Future<bool> getAutoClassify() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoClassify) ?? true;
  }

  /// 메모를 저장할 때 분류를 자동으로 채워도 되는지.
  /// AI를 쓰지 않는 경우(동의 안 함·거부)에는 "자동 분류" 설정 항목이 보이지 않으므로
  /// 예전에 꺼 둔 값과 상관없이 허용한다. AI를 켠 경우에만 그 설정을 따른다.
  static Future<bool> classificationEnabled() async {
    if (await getConsent() != true) return true;
    return getAutoClassify();
  }

  static Future<void> setAutoClassify(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoClassify, value);
  }
}
