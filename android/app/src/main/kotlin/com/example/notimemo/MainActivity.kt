package com.example.notimemo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.notimemo/notification"
    private var methodChannel: MethodChannel? = null

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
                else -> result.notImplemented()
            }
        }
    }

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
