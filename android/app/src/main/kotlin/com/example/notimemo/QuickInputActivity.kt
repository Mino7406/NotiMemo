package com.example.notimemo

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * 위젯의 입력줄을 누르면 뜨는 작은 입력 창. 앱 전체를 열지 않고 메모를 쓰고 바로 알림에 고정한다.
 * 고정 목록은 서비스가 기록하고, 내역(`flutter.memo_list`)에는 여기서 새 항목을 맨 앞에 넣는다.
 */
class QuickInputActivity : Activity() {
    private lateinit var input: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_input)
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE or WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        )
        input = findViewById(R.id.quick_memo)
        findViewById<TextView>(R.id.quick_cancel).setOnClickListener { finish() }
        findViewById<TextView>(R.id.quick_pin).setOnClickListener { pin() }
        input.requestFocus()
    }

    // 입력한 메모를 알림에 고정한다: 권한 확인 → 서비스 시작 → 내역 저장 → 위젯 갱신
    private fun pin() {
        val memo = input.text.toString().trim()
        if (memo.isEmpty()) {
            Toast.makeText(this, "메모를 입력해주세요.", Toast.LENGTH_SHORT).show()
            return
        }
        // 알림 권한이 없으면 여기서는 요청할 수 없으니 앱을 열어 안내하게 한다.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            Toast.makeText(this, "알림 권한이 꺼져 있어요. 앱에서 켜 주세요.", Toast.LENGTH_LONG).show()
            startActivity(Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            finish()
            return
        }

        val now = System.currentTimeMillis()
        // 앱의 id 규칙(마이크로초 기반 문자열)과 맞춘다.
        val id = (now * 1000L).toString()
        try {
            ContextCompat.startForegroundService(
                this,
                Intent(this, NotiMemoService::class.java)
                    .putExtra(NotiMemoService.EXTRA_MEMO, memo)
                    .putExtra(NotiMemoService.EXTRA_ID, id)
                    .putExtra(NotiMemoService.EXTRA_TIME, now)
            )
        } catch (e: Exception) {
            Toast.makeText(this, "알림을 고정하지 못했어요.", Toast.LENGTH_SHORT).show()
            return
        }
        addToHistory(id, memo, now)
        sendBroadcast(Intent("com.example.notimemo.DISMISSED").apply { setPackage(packageName) })
        NotiMemoWidget.refresh(this)
        vibrateIfEnabled()
        Toast.makeText(this, "알림이 고정되었습니다!", Toast.LENGTH_SHORT).show()
        finish()
    }

    // 앱의 내역 목록(flutter.memo_list) 맨 앞에 새 메모를 끼워 넣는다
    private fun addToHistory(id: String, memo: String, time: Long) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val old = try {
            JSONArray(prefs.getString("flutter.memo_list", null) ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
        val list = JSONArray().put(JSONObject().put("id", id).put("memo", memo).put("time", time))
        for (i in 0 until old.length()) list.put(old.get(i))
        prefs.edit().putString("flutter.memo_list", list.toString()).apply()
    }

    @Suppress("DEPRECATION")
    // 설정에서 진동이 켜져 있을 때만 진동한다
    private fun vibrateIfEnabled() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("flutter.vibration_on", true)) return
        try {
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
        } catch (e: Exception) {
            // 진동이 안 돼도 고정에는 영향이 없다.
        }
    }
}
