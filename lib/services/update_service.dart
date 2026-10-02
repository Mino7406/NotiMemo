import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';

// GitHub 최신 릴리스의 버전 태그와 지금 설치된 버전을 비교해서 업데이트가 있는지 확인한다
class UpdateService {
  static const _apiUrl =
      'https://api.github.com/repos/Mino7406/NotiMemo/releases/latest';
  static const releasesUrl =
      'https://github.com/Mino7406/NotiMemo/releases/latest';

  /// 시험에서 네트워크 대신 쓸 결과를 돌려주는 함수.
  @visibleForTesting
  static Future<UpdateResult> Function()? debugCheck;

  /// 홈 화면이 열릴 때의 조용한 확인: 새 버전이 있으면 그 버전, 아니면(실패 포함) null.
  static Future<String?> checkForUpdate() async {
    final r = await check();
    return r.status == UpdateStatus.available ? r.version : null;
  }

  /// 최신 릴리스를 확인한다. 새 버전이 있는지, 최신인지, 확인에 실패했는지를 구분해 돌려준다.
  static Future<UpdateResult> check() async {
    if (debugCheck != null) return debugCheck!();
    try {
      return await _fetch().timeout(const Duration(seconds: 8));
    } catch (_) {
      return const UpdateResult(UpdateStatus.failed);
    }
  }

  static Future<UpdateResult> _fetch() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(Uri.parse(_apiUrl));
      request.headers.set('User-Agent', 'NotiMemo-App');
      final response = await request.close();
      if (response.statusCode != 200) {
        return const UpdateResult(UpdateStatus.failed);
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      // 태그가 v3.0.0 처럼 v로 시작하면 v를 뗀다
      final tag = (json['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
      return _isNewer(tag, current)
          ? UpdateResult(UpdateStatus.available, tag)
          : const UpdateResult(UpdateStatus.upToDate);
    } finally {
      client.close();
    }
  }

  // 1.2.3 같은 버전을 점(.)으로 나눠서 앞자리부터 차례로 비교한다
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

enum UpdateStatus { available, upToDate, failed }

class UpdateResult {
  final UpdateStatus status;

  /// [UpdateStatus.available]일 때의 새 버전(예: `3.0.0`).
  final String? version;
  const UpdateResult(this.status, [this.version]);
}
