import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/memo_entry.dart';
import '../storage/settings_storage.dart';

class NotificationService {
  static const _channel = MethodChannel('com.example.notimemo/notification');

  static Future<void> initialize() async {}

  /// 설정에서 진동이 켜져 있으면 짧게 진동한다(알림 생성·예약 완료·재게시 때).
  static Future<void> vibrate() async {
    try {
      if (!await SettingsStorage.getVibration()) return;
      await _channel.invokeMethod('vibrate');
    } catch (_) {
      // 진동이 안 돼도 동작에는 영향이 없다.
    }
  }

  /// 고정 목록엔 있는데 알림창엔 알림이 하나도 없으면(앱 재설치·강제 종료로 서비스가 죽은 뒤)
  /// 저장된 목록대로 알림을 다시 게시한다. 화면의 "고정됨" 표시와 실제 알림을 맞추기 위함.
  static Future<void> restorePinned() async {
    try {
      await _channel.invokeMethod('restorePinned');
    } catch (_) {
      // 복구 실패가 앱 사용을 막지 않게 한다(테스트처럼 네이티브가 없는 환경 포함).
    }
  }

  /// 알림이 지워지거나 고쳐지거나 예약이 고정되는 등 고정 상태가 바뀌면 [onChanged]가 불린다.
  static void listenForChanges(void Function() onChanged) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationDismissed') onChanged();
    });
  }

  static Future<void> schedule(MemoEntry entry, DateTime at) async {
    await _channel.invokeMethod('schedule', {
      'id': entry.id,
      'memo': entry.memo,
      'at': at.millisecondsSinceEpoch,
    });
  }

  static Future<void> cancelSchedule(String id) async {
    await _channel.invokeMethod('cancelSchedule', {'id': id});
  }

  /// 정확한 알람 권한이 있는지 (Android 12 미만은 항상 true).
  static Future<bool> canScheduleExact() async =>
      await _channel.invokeMethod<bool>('canScheduleExact') ?? true;

  static Future<void> requestExactAlarm() async {
    await _channel.invokeMethod('requestExactAlarm');
  }

  static Future<void> show(MemoEntry entry) async {
    await _channel.invokeMethod('show', {
      'id': entry.id,
      'memo': entry.memo,
      'time': entry.time,
    });
  }

  /// [id]가 null이면 고정된 메모를 전부 해제한다.
  static Future<void> cancel([String? id]) async {
    await _channel.invokeMethod('cancel', {'id': id});
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 알림 권한을 확인하고 필요하면 요청한다.
  /// 사용 가능하면 null, 아니면 사용자에게 보여줄 오류 메시지를 반환한다.
  static Future<String?> ensurePermission() async {
    final status = await checkPermission();
    if (status == 'permanentlyDenied') {
      return '알림 권한이 차단되었습니다. 설정에서 허용해주세요.';
    }
    if (status != 'granted' && !await requestPermission()) {
      return '알림 권한이 필요합니다.';
    }
    return null;
  }

  // Returns: 'granted', 'denied', 'permanentlyDenied'
  static Future<String> checkPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return 'granted';
    if (status.isPermanentlyDenied) return 'permanentlyDenied';
    return 'denied';
  }
}
