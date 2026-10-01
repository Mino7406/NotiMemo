import 'package:shared_preferences/shared_preferences.dart';

/// 첫 실행 튜토리얼을 이미 봤는지 저장한다.
class TutorialStorage {
  static const _keySeen = 'tutorial_seen';

  static Future<bool> getSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySeen) ?? false;
  }

  static Future<void> setSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySeen, true);
  }
}
