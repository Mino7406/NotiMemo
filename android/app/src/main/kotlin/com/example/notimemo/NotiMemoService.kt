package com.example.notimemo

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Typeface
import android.os.Build
import android.os.IBinder
import android.text.SpannableString
import android.text.style.StyleSpan
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class NotiMemoService : Service() {
    companion object {
        const val CHANNEL_ID = "notimemo_fg_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_STOP = "com.example.notimemo.STOP"
        const val ACTION_REPOST = "com.example.notimemo.REPOST"
        const val EXTRA_MEMO = "memo"
        private const val PREFS_NAME = "notimemo_prefs"
        private const val PREF_MEMO = "current_memo"
        private const val PREF_TIME = "created_time"
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                clearSavedMemo()
                getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .remove("flutter.saved_memo")
                    .remove("flutter.notification_active")
                    .apply()
                sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply {
                    setPackage(packageName)
                })
                ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_REPOST -> {
                val memo = intent.getStringExtra(EXTRA_MEMO) ?: getSavedMemo() ?: return START_NOT_STICKY
                showNotification(memo, getSavedTime())
                return START_STICKY
            }
            else -> {
                val memo = intent?.getStringExtra(EXTRA_MEMO) ?: getSavedMemo() ?: return START_NOT_STICKY
                val now = System.currentTimeMillis()
                saveMemo(memo, now)
                showNotification(memo, now)
                return START_STICKY
            }
        }
    }

    private fun showNotification(memo: String, createdAt: Long) {
        ensureChannel()

        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, NotiMemoService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val repostIntent = PendingIntent.getService(
            this, 2,
            Intent(this, NotiMemoService::class.java).apply {
                action = ACTION_REPOST
                putExtra(EXTRA_MEMO, memo)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val boldMemo = SpannableString(memo).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, memo.length, 0)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notify_white)
            .setContentText(boldMemo)
            .setOngoing(true)
            .setSilent(true)
            .setWhen(createdAt)
            .setShowWhen(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "지우기", stopIntent)
            .setDeleteIntent(repostIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun saveMemo(memo: String, time: Long) {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .putString(PREF_MEMO, memo)
            .putLong(PREF_TIME, time)
            .apply()
    }

    private fun getSavedTime(): Long =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(PREF_TIME, System.currentTimeMillis())

    private fun getSavedMemo(): String? =
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).getString(PREF_MEMO, null)

    private fun clearSavedMemo() {
        getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
            .remove(PREF_MEMO)
            .remove(PREF_TIME)
            .apply()
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(CHANNEL_ID, "알림메모", NotificationManager.IMPORTANCE_LOW).apply {
            description = "알림 메모를 표시합니다"
            setSound(null, null)
            enableLights(false)
            enableVibration(false)
        }
        nm.createNotificationChannel(channel)
    }
}
