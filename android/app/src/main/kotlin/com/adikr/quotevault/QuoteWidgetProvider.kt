package com.adikr.quotevault // <--- CHECK THIS MATCHES YOUR PACKAGE

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class QuoteWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {

                // 1. Get & Set Text
                val quote = widgetData.getString("quote_text", "Open App for Daily Truth")
                val author = widgetData.getString("quote_author", "")
                setTextViewText(R.id.widget_quote_text, "\"$quote\"")
                setTextViewText(R.id.widget_author_text, "- $author")

                // 2. Create Intent to Launch App
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    // These flags clear the stack so the app opens fresh or brings existing to front
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

                // 3. Wrap in PendingIntent (Required for Widgets)
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // 4. Attach Click Listener to the Root Layout
                // "widget_root" must match the ID in your XML layout
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}