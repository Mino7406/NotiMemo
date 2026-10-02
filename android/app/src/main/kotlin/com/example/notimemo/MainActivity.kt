package com.example.notimemo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Flutter 화면을 띄우는 액티비티. Flutter에서 오는 요청(알림 고정, 예약, 진동 등)을 받아서 처리한다
class MainActivity : FlutterActivity() {
    // Flutter 쪽 NotificationService의 채널 이름과 같아야 한다
    private val channel = "com.example.notimemo/notification"
    private var methodChannel: MethodChannel? = null

    /** 위젯에서 항목을 눌러 열렸을 때 앱이 열어야 할 화면(`history`/`scheduled`). Flutter가 가져가면 비운다. */
    private var pendingTarget: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingTarget = intent?.getStringExtra("open")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val target = intent.getStringExtra("open") ?: return
        // 이미 실행 중이면 바로 알리고, 아니면 Flutter가 시작할 때 가져가도록 남겨 둔다.
        pendingTarget = target
        methodChannel?.invokeMethod("openTarget", target)
    }

    // 알림이 바뀌었다는 방송을 받으면 Flutter에 알려서 화면을 새로 읽게 한다
    private val dismissedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            methodChannel?.invokeMethod("notificationDismissed", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // 메모를 알림창에 고정: 서비스를 시작하면서 메모 내용을 넘긴다
                "show" -> {
                    val memo = call.argument<String>("memo") ?: ""
                    val intent = Intent(this, NotiMemoService::class.java).apply {
                        putExtra(NotiMemoService.EXTRA_MEMO, memo)
                        call.argument<String>("id")?.let { putExtra(NotiMemoService.EXTRA_ID, it) }
                        call.argument<Number>("time")?.let { putExtra(NotiMemoService.EXTRA_TIME, it.toLong()) }
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                // id가 있으면 그 알림만, 없으면 전부 내린다
                "cancel" -> {
                    val id = call.argument<String>("id")
                    startService(Intent(this, NotiMemoService::class.java).apply {
                        if (id != null) {
                            action = NotiMemoService.ACTION_STOP
                            putExtra(NotiMemoService.EXTRA_ID, id)
                        } else {
                            action = NotiMemoService.ACTION_STOP_ALL
                        }
                    })
                    result.success(null)
                }
                "getLaunchTarget" -> {
                    result.success(pendingTarget)
                    pendingTarget = null
                }
                "refreshWidget" -> {
                    NotiMemoWidget.refresh(this)
                    result.success(null)
                }
                "vibrate" -> {
                    vibrateShort()
                    result.success(null)
                }
                "restorePinned" -> {
                    restorePinnedIfMissing()
                    result.success(null)
                }
                // 예약 알람 등록
                "schedule" -> {
                    val id = call.argument<String>("id")
                    val memo = call.argument<String>("memo")
                    val at = call.argument<Number>("at")?.toLong()
                    if (id == null || memo == null || at == null) {
                        result.error("bad_args", "id, memo, at 필요", null)
                    } else {
                        AlarmScheduler.schedule(this, id, memo, at)
                        result.success(null)
                    }
                }
                "cancelSchedule" -> {
                    call.argument<String>("id")?.let { AlarmScheduler.cancel(this, it) }
                    result.success(null)
                }
                // 정확한 알람을 쓸 수 있는지 확인
                "canScheduleExact" -> result.success(AlarmScheduler.canScheduleExact(this))
                // 안드로이드 12 이상에서 정확한 알람 허용 설정 화면을 연다
                "requestExactAlarm" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                        })
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    // 60ms 정도 짧게 진동한다(안드로이드 버전마다 방법이 달라서 나눠 처리)
    private fun vibrateShort() {
        val v = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(android.os.VibratorManager::class.java).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as android.os.Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            v.vibrate(android.os.VibrationEffect.createOneShot(60, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            v.vibrate(60)
        }
    }

    /** 고정 목록(prefs)은 있는데 우리 알림이 하나도 안 떠 있으면 서비스를 깨워 다시 게시한다. */
    private fun restorePinnedIfMissing() {
        val raw = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.pinned_notes", null)
        if (raw.isNullOrEmpty() || raw == "[]") return
        val nm = getSystemService(android.app.NotificationManager::class.java)
        if (nm.activeNotifications.any { it.packageName == packageName && it.id != 0 }) return
        val intent = Intent(this, NotiMemoService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
    }

    // 화면이 보이는 동안만 알림 변경 방송을 듣는다
    override fun onStart() {
        super.onStart()
        val filter = IntentFilter("com.example.notimemo.DISMISSED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissedReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(dismissedReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        unregisterReceiver(dismissedReceiver)
    }
}
