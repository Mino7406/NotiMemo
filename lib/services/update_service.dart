import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/Mino7406/NotiMemo/releases/latest';
  static const releasesUrl =
      'https://github.com/Mino7406/NotiMemo/releases/latest';

  /// Returns the latest version tag if newer than the current version, null otherwise.
  static Future<String?> checkForUpdate() async {
    try {
      return await _fetch().timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetch() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('User-Agent', 'NotiMemo-App');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
      return _isNewer(tag, current) ? tag : null;
    } finally {
      client.close();
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
