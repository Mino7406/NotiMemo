package com.example.notimemo

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * 예약 고정. 예약 목록은 Flutter와 공유하는 prefs(`flutter.scheduled_notes`)가 유일한 저장소이고
 * 네이티브만 쓴다. 시각이 되면 [AlarmReceiver]가 [fire]를 불러 메모를 고정한다.
 */
object AlarmScheduler {
    const val ACTION_FIRE = "com.example.notimemo.SCHEDULE_FIRE"
    const val EXTRA_ID = "id"

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PREF_SCHEDULED = "flutter.scheduled_notes"

    class Scheduled(val id: String, val memo: String, val at: Long)

    fun load(ctx: Context): List<Scheduled> {
        val raw = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .getString(PREF_SCHEDULED, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Scheduled(o.getString("id"), o.getString("memo"), o.getLong("at"))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun save(ctx: Context, list: List<Scheduled>) {
        val editor = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).edit()
        if (list.isEmpty()) {
            editor.remove(PREF_SCHEDULED)
        } else {
            val arr = JSONArray()
            list.forEach {
                arr.put(JSONObject().put("id", it.id).put("memo", it.memo).put("at", it.at))
            }
            editor.putString(PREF_SCHEDULED, arr.toString())
        }
        editor.apply()
    }

    fun canScheduleExact(ctx: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ctx.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()

    fun schedule(ctx: Context, id: String, memo: String, at: Long) {
        val s = Scheduled(id, memo, at)
        save(ctx, load(ctx).filter { it.id != id } + s)
        setAlarm(ctx, s)
    }

    fun cancel(ctx: Context, id: String) {
        save(ctx, load(ctx).filter { it.id != id })
        ctx.getSystemService(AlarmManager::class.java).cancel(pendingIntent(ctx, id))
    }

    /** 재부팅·앱 업데이트 뒤 알람을 복원한다. 이미 지난 예약은 바로 게시한다. */
    fun restoreAll(ctx: Context) {
        val now = System.currentTimeMillis()
        for (s in load(ctx)) {
            if (s.at <= now) fire(ctx, s.id, allowForeground = false) else setAlarm(ctx, s)
        }
    }

    /**
     * 예약 시각이 된 메모를 고정한다.
     * [allowForeground]가 false면(부팅 직후 등 포그라운드 서비스를 시작할 수 없는 경우)
     * 고정 대신 일반 알림으로 알린다.
     */
    fun fire(ctx: Context, id: String, allowForeground: Boolean = true) {
        val all = load(ctx)
        val s = all.firstOrNull { it.id == id } ?: return
        save(ctx, all.filter { it.id != id })

        var pinned = false
        if (allowForeground) {
            try {
                ContextCompat.startForegroundService(
                    ctx,
                    Intent(ctx, NotiMemoService::class.java)
                        .putExtra(NotiMemoService.EXTRA_MEMO, s.memo)
                        .putExtra(NotiMemoService.EXTRA_ID, s.id)
                        .putExtra(NotiMemoService.EXTRA_TIME, s.at)
                )
                pinned = true
            } catch (e: Exception) {
                // 백그라운드에서 포그라운드 서비스를 시작할 수 없으면 아래 일반 알림으로 대체
            }
        }
        if (!pinned) postPlain(ctx, s)
        ctx.sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply { setPackage(ctx.packageName) })
    }

    private fun postPlain(ctx: Context, s: Scheduled) {
        NotiMemoService.ensureChannel(ctx)
        val open = PendingIntent.getActivity(
            ctx, 1,
            Intent(ctx, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val n = NotificationCompat.Builder(ctx, NotiMemoService.CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notify_white)
            .setContentTitle("알림메모")
            .setContentText(s.memo)
            .setStyle(NotificationCompat.BigTextStyle().bigText(s.memo))
            .setContentIntent(open)
            .setAutoCancel(true)
            .setWhen(s.at)
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(s.id.hashCode(), n)
    }

    private fun setAlarm(ctx: Context, s: Scheduled) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        val pi = pendingIntent(ctx, s.id)
        if (canScheduleExact(ctx)) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.at, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, s.at, pi)
        }
    }

    /** 예약마다 서로 다른 PendingIntent가 되도록 data URI로 구분한다. */
    private fun pendingIntent(ctx: Context, id: String): PendingIntent =
        PendingIntent.getBroadcast(
            ctx, 0,
            Intent(ctx, AlarmReceiver::class.java).apply {
                action = ACTION_FIRE
                data = Uri.parse("notimemo://schedule/${Uri.encode(id)}")
                putExtra(EXTRA_ID, id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
}

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(AlarmScheduler.EXTRA_ID) ?: return
        AlarmScheduler.fire(context, id)
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON" -> AlarmScheduler.restoreAll(context)
        }
    }
}
