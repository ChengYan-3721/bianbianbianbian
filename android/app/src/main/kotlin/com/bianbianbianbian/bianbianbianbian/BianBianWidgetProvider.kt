package com.bianbianbianbian.bianbianbianbian

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews

import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Step 16.3：桌面小组件 Provider——展示"今日支出"与"本月结余"。
 *
 * 数据来源：Flutter 侧 [WidgetDataService] 通过 `home_widget` 包写入
 * SharedPreferences（文件名 `HomeWidgetPreferences`），本 Provider 在
 * `onUpdate` 中读取并填充 [RemoteViews]。
 *
 * 点击行为：PendingIntent 打开主 Activity 并携带 `bianbian://record/new`
 * URI，Flutter 侧 go_router 处理深链跳转到"新建记账页"。
 */
class BianBianWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val KEY_TODAY_EXPENSE = "widget_today_expense"
        private const val KEY_MONTHLY_BALANCE = "widget_monthly_balance"
        private const val KEY_LEDGER_NAME = "widget_ledger_name"
        private const val DEEP_LINK_SCHEME = "bianbian"
        private const val DEEP_LINK_PATH = "/record/new"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val todayExpense = widgetData.getString(KEY_TODAY_EXPENSE, "¥0.00") ?: "¥0.00"
        val monthlyBalance = widgetData.getString(KEY_MONTHLY_BALANCE, "¥0.00") ?: "¥0.00"
        val ledgerName = widgetData.getString(KEY_LEDGER_NAME, "边边记账") ?: "边边记账"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.bianbian_widget)

            views.setTextViewText(R.id.widget_today_expense, todayExpense)
            views.setTextViewText(R.id.widget_monthly_balance, monthlyBalance)
            views.setTextViewText(R.id.widget_ledger_name, ledgerName)

            // 结余为负时变色（与 App 内一致——负数用苹果红 #E76F51）
            val balanceValue = parseAmount(monthlyBalance)
            views.setTextColor(
                R.id.widget_monthly_balance,
                if (balanceValue < 0) 0xFFE76F51.toInt() else 0xFF8A5A3B.toInt()
            )

            // 点击整个 widget → 深链到新建记账页
            val deepLinkIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("$DEEP_LINK_SCHEME://app$DEEP_LINK_PATH")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                deepLinkIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /** 从格式化金额字符串中提取数值，如 `"¥25.00"` → 25.0, `"-¥30.00"` → -30.0。 */
    private fun parseAmount(formatted: String): Double {
        val cleaned = formatted.replace("¥", "").replace(",", "").trim()
        return cleaned.toDoubleOrNull() ?: 0.0
    }
}
