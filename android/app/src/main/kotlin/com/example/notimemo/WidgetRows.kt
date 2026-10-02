package com.example.notimemo

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** 위젯 목록의 한 줄. [label]은 "학교 · 우선순위 보통"(분류가 없으면 빈 문자열). */
class WidgetRow(val label: String, val memo: String, val time: String)

/**
 * 위젯에 보여줄 줄을 prefs의 JSON에서 만든다. 안드로이드 화면과 무관한 순수 함수라서
 * 깨진 JSON이어도 빈 목록으로 안전하게 돌아온다.
 */
object WidgetRows {
    private const val MAX_ROWS = 50

    /** 예약 목록(시각 순). 분류는 같은 id의 히스토리 항목에서 가져온다. */
    fun scheduled(scheduledRaw: String?, historyRaw: String?): List<WidgetRow> {
        if (scheduledRaw.isNullOrEmpty()) return emptyList()
        return try {
            val history = historyById(historyRaw)
            val arr = JSONArray(scheduledRaw)
            (0 until arr.length())
                .map { arr.getJSONObject(it) }
                .sortedBy { it.optLong("at", 0L) }
                .take(MAX_ROWS)
                .map { o ->
                    WidgetRow(
                        label = labelOf(history[o.optString("id")]),
                        memo = o.optString("memo"),
                        time = formatTime(o.optLong("at", 0L)),
                    )
                }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /** 알림 내역(저장된 순서 = 최신순). 옛 포맷(문자열만 있는 항목)도 읽는다. */
    fun history(historyRaw: String?): List<WidgetRow> {
        if (historyRaw.isNullOrEmpty()) return emptyList()
        return try {
            val arr = JSONArray(historyRaw)
            (0 until arr.length()).take(MAX_ROWS).map { i ->
                when (val item = arr.get(i)) {
                    is JSONObject -> WidgetRow(
                        label = labelOf(item),
                        memo = item.optString("memo"),
                        time = formatTime(item.optLong("time", 0L)),
                    )
                    else -> WidgetRow("", item.toString(), "")
                }
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun historyById(raw: String?): Map<String, JSONObject> {
        if (raw.isNullOrEmpty()) return emptyMap()
        return try {
            val arr = JSONArray(raw)
            val map = HashMap<String, JSONObject>()
            for (i in 0 until arr.length()) {
                val o = arr.opt(i) as? JSONObject ?: continue
                val id = o.optString("id")
                if (id.isNotEmpty()) map[id] = o
            }
            map
        } catch (e: Exception) {
            emptyMap()
        }
    }

    private fun labelOf(entry: JSONObject?): String {
        val category = entry?.optString("category").orEmpty()
        if (category.isEmpty()) return ""
        val priority = when (entry?.optString("priority")) {
            "high" -> "높음"
            "low" -> "낮음"
            else -> "보통"
        }
        return "$category · 우선순위 $priority"
    }

    /** "10월 2일 (금) 오후 3:30". 시각을 모르면(0) 빈 문자열. */
    fun formatTime(ms: Long): String {
        if (ms <= 0L) return ""
        return SimpleDateFormat("M월 d일 (E) a h:mm", Locale.KOREAN).format(Date(ms))
    }
}
