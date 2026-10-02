package com.example.notimemo

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.text.SpannableString
import android.text.style.StyleSpan
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import androidx.core.app.ServiceCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * 고정된 메모마다 알림을 하나씩 게시한다.
 * 포그라운드 서비스는 그중 하나(앵커)를 startForeground로 붙들고, 나머지는 notify로 게시한다.
 * 고정 목록은 Flutter와 공유하는 prefs(`flutter.pinned_notes`)가 유일한 저장소다.
 */
class NotiMemoService : Service() {
    companion object {
        const val CHANNEL_ID = "notimemo_fg_channel"
        const val GROUP_KEY = "notimemo_group"
        const val ACTION_STOP = "com.example.notimemo.STOP"
        const val ACTION_STOP_ALL = "com.example.notimemo.STOP_ALL"
        const val ACTION_REPOST = "com.example.notimemo.REPOST"
        const val ACTION_EDIT = "com.example.notimemo.EDIT"
        const val EXTRA_ID = "id"
        const val EXTRA_MEMO = "memo"
        const val EXTRA_TIME = "time"
        const val KEY_REPLY = "reply_text"

        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val PREF_PINNED = "flutter.pinned_notes"
        private const val PREF_HISTORY = "flutter.memo_list"

        // 멀티 메모 이전 버전이 쓰던 단일 메모 저장소 (마이그레이션용)
        private const val LEGACY_PREFS = "notimemo_prefs"
        private const val LEGACY_MEMO = "current_memo"
        private const val LEGACY_TIME = "created_time"
        private const val LEGACY_ID = "legacy_current"

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(NotificationManager::class.java)
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

    private class Note(val id: String, val memo: String, val time: Long)

    private var anchorId: String? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        migrateLegacy()
        when (intent?.action) {
            ACTION_STOP -> {
                val id = intent.getStringExtra(EXTRA_ID)
                if (id != null) removeNote(id)
                return afterChange()
            }
            ACTION_STOP_ALL -> {
                savePinned(emptyList())
                return afterChange()
            }
            ACTION_EDIT -> {
                val id = intent.getStringExtra(EXTRA_ID) ?: return stickyIfAny()
                val note = loadPinned().firstOrNull { it.id == id } ?: return stickyIfAny()
                val text = RemoteInput.getResultsFromIntent(intent)
                    ?.getCharSequence(KEY_REPLY)?.toString()?.trim()
                // 빈 입력이면 원래 알림을 다시 게시해서 입력창만 닫는다.
                val updated = if (text.isNullOrEmpty()) note else Note(id, text, note.time)
                if (updated !== note) {
                    savePinned(loadPinned().map { if (it.id == id) updated else it })
                    updateHistory(id, text!!)
                }
                post(updated)
                sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply { setPackage(packageName) })
                return START_STICKY
            }
            ACTION_REPOST -> {
                val id = intent.getStringExtra(EXTRA_ID) ?: return stickyIfAny()
                val note = loadPinned().firstOrNull { it.id == id } ?: return stickyIfAny()
                post(note)
                return START_STICKY
            }
            else -> {
                val memo = intent?.getStringExtra(EXTRA_MEMO)
                if (memo == null) {
                    // 시스템이 서비스를 되살린 경우: 저장된 고정 목록을 전부 다시 게시
                    loadPinned().forEach { post(it) }
                    return stickyIfAny()
                }
                val id = intent.getStringExtra(EXTRA_ID) ?: System.currentTimeMillis().toString()
                val time = intent.getLongExtra(EXTRA_TIME, System.currentTimeMillis())
                val note = Note(id, memo, time)
                val list = loadPinned().filter { it.id != id } + note
                savePinned(list)
                post(note)
                return START_STICKY
            }
        }
    }

    private fun stickyIfAny(): Int {
        if (loadPinned().isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    /** 고정 목록이 바뀐 뒤: 비었으면 서비스를 끝내고, 앵커가 사라졌으면 다른 메모로 옮긴다. */
    private fun afterChange(): Int {
        val remaining = loadPinned()
        if (remaining.isEmpty()) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            getSystemService(NotificationManager::class.java).cancelAll()
            anchorId = null
            sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply { setPackage(packageName) })
            stopSelf()
            return START_NOT_STICKY
        }
        val anchor = anchorId
        if (anchor == null || remaining.none { it.id == anchor }) {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
            anchorId = null
            remaining.forEach { post(it) }
        }
        sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply { setPackage(packageName) })
        return START_STICKY
    }

    private fun post(note: Note) {
        ensureChannel()
        val notification = buildNotification(note)
        val nid = notifId(note.id)
        if (anchorId == null || anchorId == note.id) {
            anchorId = note.id
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(nid, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(nid, notification)
            }
        } else {
            getSystemService(NotificationManager::class.java).notify(nid, notification)
        }
    }

    private fun buildNotification(note: Note): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this, 1,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = servicePendingIntent(note.id, ACTION_STOP)
        val repostIntent = servicePendingIntent(note.id, ACTION_REPOST)
        val editIntent = PendingIntent.getService(
            this, 0,
            Intent(this, NotiMemoService::class.java).apply {
                action = ACTION_EDIT
                data = Uri.parse("notimemo://memo/${Uri.encode(note.id)}/edit")
                putExtra(EXTRA_ID, note.id)
            },
            // RemoteInput 결과가 채워지려면 가변이어야 한다.
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
        )
        val editAction = NotificationCompat.Action.Builder(0, "수정", editIntent)
            .addRemoteInput(RemoteInput.Builder(KEY_REPLY).setLabel("수정할 내용").build())
            .setAllowGeneratedReplies(false)
            .build()

        val boldMemo = SpannableString(note.memo).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, note.memo.length, 0)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notify_white)
            .setContentTitle("알림메모")
            .setContentIntent(openAppIntent)
            .setContentText(boldMemo)
            .setStyle(NotificationCompat.BigTextStyle().bigText(boldMemo))
            .setOngoing(true)
            .setSilent(true)
            .setWhen(note.time)
            .setShowWhen(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setGroup(GROUP_KEY)
            .addAction(editAction)
            .addAction(0, "지우기", stopIntent)
            .setDeleteIntent(repostIntent)
            .build()
    }

    /** 메모마다 서로 다른 PendingIntent가 되도록 data URI로 구분한다. */
    private fun servicePendingIntent(id: String, action: String): PendingIntent =
        PendingIntent.getService(
            this, 0,
            Intent(this, NotiMemoService::class.java).apply {
                this.action = action
                data = Uri.parse("notimemo://memo/${Uri.encode(id)}/$action")
                putExtra(EXTRA_ID, id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    private fun notifId(id: String): Int {
        val h = id.hashCode()
        return if (h == 0) 1 else h
    }

    // ── 저장소 ──────────────────────────────────────────────

    private fun flutterPrefs() = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    private fun loadPinned(): List<Note> {
        val raw = flutterPrefs().getString(PREF_PINNED, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Note(o.getString("id"), o.getString("memo"), o.optLong("time", 0L))
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun savePinned(list: List<Note>) {
        val editor = flutterPrefs().edit()
        if (list.isEmpty()) {
            editor.remove(PREF_PINNED)
        } else {
            val arr = JSONArray()
            list.forEach {
                arr.put(JSONObject().put("id", it.id).put("memo", it.memo).put("time", it.time))
            }
            editor.putString(PREF_PINNED, arr.toString())
        }
        editor.apply()
    }

    private fun removeNote(id: String) {
        savePinned(loadPinned().filter { it.id != id })
        getSystemService(NotificationManager::class.java).cancel(notifId(id))
    }

    /** 알림에서 고친 내용을 앱의 히스토리(`memo_list`)에도 반영한다. */
    private fun updateHistory(id: String, memo: String) {
        val prefs = flutterPrefs()
        val raw = prefs.getString(PREF_HISTORY, null) ?: return
        try {
            val arr = JSONArray(raw)
            var changed = false
            for (i in 0 until arr.length()) {
                val item = arr.get(i)
                when {
                    item is JSONObject && item.optString("id") == id -> {
                        item.put("memo", memo)
                        changed = true
                    }
                    // 옛 포맷(문자열)의 id는 위치 기반(legacy_i)이라 객체로 바꿔 저장한다.
                    item is String && id == "legacy_$i" -> {
                        arr.put(i, JSONObject().put("id", id).put("memo", memo).put("time", 0))
                        changed = true
                    }
                }
            }
            if (changed) {
                prefs.edit().putString(PREF_HISTORY, arr.toString()).apply()
                NotiMemoWidget.refresh(this)
            }
        } catch (e: Exception) {
            // 히스토리가 깨져 있어도 알림 수정은 계속한다.
        }
    }

    /** 멀티 메모 이전 버전의 단일 메모를 고정 목록으로 한 번 옮긴다. */
    private fun migrateLegacy() {
        val legacy = getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
        val memo = legacy.getString(LEGACY_MEMO, null) ?: return
        val time = legacy.getLong(LEGACY_TIME, System.currentTimeMillis())
        val list = loadPinned()
        if (list.none { it.id == LEGACY_ID }) savePinned(list + Note(LEGACY_ID, memo, time))
        legacy.edit().remove(LEGACY_MEMO).remove(LEGACY_TIME).apply()
    }

    private fun ensureChannel() = ensureChannel(this)
}
