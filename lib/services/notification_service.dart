import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static const _channel = MethodChannel('com.example.notimemo/notification');

  static Future<void> initialize() async {}

  static Future<void> show(String memo) async {
    await _channel.invokeMethod('show', {'memo': memo});
  }

  static Future<void> cancel() async {
    await _channel.invokeMethod('cancel');
  }

  static Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}
