package com.example.notimemo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService

/**
 * 홈 화면 위젯 하나: 위쪽 입력줄(누르면 빠른 입력 창) + `예약`/`내역` 탭 + 목록.
 * 데이터는 앱과 공유하는 prefs를 그대로 읽고, 바뀌면 [refresh]로 다시 그린다.
 */
class NotiMemoWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_TAB = "com.example.notimemo.WIDGET_TAB"
        const val EXTRA_TAB = "tab"
        const val TAB_SCHEDULED = 0
        const val TAB_HISTORY = 1

        private const val PREFS = "notimemo_widget"
        private const val KEY_TAB = "tab"
        private val INACTIVE_TAB_TEXT = Color.parseColor("#FF8B93A7")

        // 위젯에서 마지막으로 고른 탭(예약/내역)
        fun currentTab(ctx: Context): Int =
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt(KEY_TAB, TAB_SCHEDULED)

        /** 모든 위젯의 화면과 목록을 다시 그린다. 위젯이 없으면 아무것도 하지 않는다. */
        fun refresh(ctx: Context) {
            try {
                val mgr = AppWidgetManager.getInstance(ctx)
                val ids = mgr.getAppWidgetIds(ComponentName(ctx, NotiMemoWidget::class.java))
                if (ids.isEmpty()) return
                update(ctx, mgr, ids)
            } catch (e: Exception) {
                // 위젯 갱신 실패가 본래 동작(고정·예약)을 막으면 안 된다.
            }
        }

        private fun update(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
            val tab = currentTab(ctx)
            for (id in ids) mgr.updateAppWidget(id, buildViews(ctx, id, tab))
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        }

        // 위젯 화면 하나를 만들고 누를 곳마다 동작을 연결한다
        private fun buildViews(ctx: Context, widgetId: Int, tab: Int): RemoteViews {
            val views = RemoteViews(ctx.packageName, R.layout.widget_main)
            val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

            // 입력줄 → 빠른 입력 창
            views.setOnClickPendingIntent(
                R.id.widget_input,
                PendingIntent.getActivity(
                    ctx, 100,
                    Intent(ctx, QuickInputActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    },
                    immutable
                )
            )

            // 탭
            for ((viewId, which) in listOf(R.id.widget_tab_sched to TAB_SCHEDULED, R.id.widget_tab_hist to TAB_HISTORY)) {
                val on = tab == which
                views.setInt(viewId, "setBackgroundResource", if (on) R.drawable.widget_tab_on else R.drawable.widget_tab_off)
                views.setTextColor(viewId, if (on) Color.WHITE else INACTIVE_TAB_TEXT)
                views.setOnClickPendingIntent(
                    viewId,
                    PendingIntent.getBroadcast(
                        ctx, 200 + which,
                        Intent(ctx, NotiMemoWidget::class.java).apply {
                            action = ACTION_TAB
                            putExtra(EXTRA_TAB, which)
                        },
                        immutable
                    )
                )
            }

            // 목록: 항목을 누르면 앱을 연다.
            val adapter = Intent(ctx, NotiMemoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_list, adapter)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)
            views.setTextViewText(
                R.id.widget_empty,
                if (tab == TAB_SCHEDULED) "예약된 메모가 없어요" else "알림 내역이 없어요"
            )
            views.setPendingIntentTemplate(
                R.id.widget_list,
                PendingIntent.getActivity(
                    ctx, 300,
                    Intent(ctx, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
            )
            return views
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        update(context, appWidgetManager, appWidgetIds)
    }

    // 위젯 크기가 바뀌면 다시 그린다
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        // 크기가 바뀌면(1칸 ↔ 여러 칸) 모양을 다시 정한다.
        update(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TAB) {
            val tab = intent.getIntExtra(EXTRA_TAB, TAB_SCHEDULED)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putInt(KEY_TAB, tab).apply()
            refresh(context)
        }
    }
}

/** 위젯 목록(`ListView`)에 줄을 공급한다. 탭에 따라 예약 또는 내역을 읽는다. */
class NotiMemoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory = Factory(applicationContext)

    private class Factory(private val ctx: Context) : RemoteViewsFactory {
        private var rows: List<WidgetRow> = emptyList()

        override fun onCreate() {}

        // 목록을 새로 그릴 때마다 prefs에서 현재 탭에 맞는 데이터를 다시 읽는다
        override fun onDataSetChanged() {
            val prefs = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val history = prefs.getString("flutter.memo_list", null)
            rows = if (NotiMemoWidget.currentTab(ctx) == NotiMemoWidget.TAB_SCHEDULED) {
                WidgetRows.scheduled(prefs.getString("flutter.scheduled_notes", null), history)
            } else {
                WidgetRows.history(history)
            }
        }

        override fun onDestroy() {}

        override fun getCount(): Int = rows.size

        // 목록의 한 줄(분류, 메모, 시간)을 만든다
        override fun getViewAt(position: Int): RemoteViews {
            val row = rows.getOrNull(position) ?: return RemoteViews(ctx.packageName, R.layout.widget_item)
            val v = RemoteViews(ctx.packageName, R.layout.widget_item)
            v.setTextViewText(R.id.widget_item_class, row.label)
            v.setViewVisibility(R.id.widget_item_class, if (row.label.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            v.setTextViewText(R.id.widget_item_memo, row.memo)
            v.setTextViewText(R.id.widget_item_time, row.time)
            v.setViewVisibility(R.id.widget_item_time, if (row.time.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            // 눌린 항목이 속한 탭에 맞는 목록(예약 목록/알림 내역)을 앱에서 바로 열게 한다.
            val target = if (NotiMemoWidget.currentTab(ctx) == NotiMemoWidget.TAB_SCHEDULED) "scheduled" else "history"
            v.setOnClickFillInIntent(R.id.widget_item_root, Intent().putExtra("open", target))
            return v
        }

        override fun getLoadingView(): RemoteViews? = null
        override fun getViewTypeCount(): Int = 1
        override fun getItemId(position: Int): Long = position.toLong()
        override fun hasStableIds(): Boolean = false
    }
}
