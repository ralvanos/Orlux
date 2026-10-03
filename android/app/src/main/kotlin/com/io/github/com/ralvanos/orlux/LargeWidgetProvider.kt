package com.io.github.com.ralvanos.orlux

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

class LargeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(id)
            appWidgetManager.updateAppWidget(
                id,
                WidgetStore.buildViews(context, R.layout.orlux_widget_4x4, options),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(
            appWidgetId,
            WidgetStore.buildViews(context, R.layout.orlux_widget_4x4, newOptions),
        )
    }
}
