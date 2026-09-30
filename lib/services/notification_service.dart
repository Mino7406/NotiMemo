import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/memo_entry.dart';

class NotificationService {
  static const _channel = MethodChannel('com.example.notimemo/notification');

  static Future<void> initialize() async {}

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
