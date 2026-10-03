package com.io.github.com.ralvanos.orlux

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

object WidgetStore {
    private const val PREFS = "orlux_widget"
    private const val KEY_ZONE = "timezone"
    private const val KEY_24 = "use24Hour"
    private const val KEY_UTC = "showUtc"
    private const val KEY_TIMER_NAME = "timerName"
    private const val KEY_TIMER_MODE = "timerMode"
    private const val KEY_TIMER_ANCHOR = "timerAnchorMs"
    private const val KEY_ALARM = "alarmLine"
    private const val KEY_SECONDS = "widgetSeconds"

    fun saveConfig(
        context: Context,
        timezone: String,
        use24Hour: Boolean,
        showUtc: Boolean,
        timerName: String,
        timerMode: String,
        timerAnchorMs: Long,
        alarmLine: String,
        widgetSeconds: Boolean,
    ) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_ZONE, timezone)
            .putBoolean(KEY_24, use24Hour)
            .putBoolean(KEY_UTC, showUtc)
            .putString(KEY_TIMER_NAME, timerName)
            .putString(KEY_TIMER_MODE, timerMode)
            .putLong(KEY_TIMER_ANCHOR, timerAnchorMs)
            .putString(KEY_ALARM, alarmLine)
            .putBoolean(KEY_SECONDS, widgetSeconds)
            .apply()
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        updateAll(context, manager, WatchWidgetProvider::class.java)
        updateAll(context, manager, LargeWidgetProvider::class.java)
    }

    private fun updateAll(
        context: Context,
        manager: AppWidgetManager,
        cls: Class<*>,
    ) {
        val ids = manager.getAppWidgetIds(ComponentName(context, cls))
        for (id in ids) {
            val options = manager.getAppWidgetOptions(id)
            val layout = if (cls == LargeWidgetProvider::class.java) {
                R.layout.orlux_widget_4x4
            } else {
                R.layout.orlux_widget_2x2
            }
            manager.updateAppWidget(id, buildViews(context, layout, options))
        }
    }

    fun buildViews(context: Context, layout: Int, options: Bundle?): RemoteViews {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val zone = prefs.getString(KEY_ZONE, "UTC") ?: "UTC"
        val use24 = prefs.getBoolean(KEY_24, true)
        val showUtc = prefs.getBoolean(KEY_UTC, true)
        val timerName = prefs.getString(KEY_TIMER_NAME, "") ?: ""
        val timerMode = prefs.getString(KEY_TIMER_MODE, "none") ?: "none"
        val timerAnchorMs = prefs.getLong(KEY_TIMER_ANCHOR, 0L)
        val alarmLine = prefs.getString(KEY_ALARM, "") ?: ""
        val widgetSeconds = prefs.getBoolean(KEY_SECONDS, true)
        val views = RemoteViews(context.packageName, layout)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        views.setOnClickPendingIntent(R.id.widget_root, open)

        val localFmt = if (use24) "HH:mm" else "h:mm a"
        applyClock(views, R.id.digital_local, zone, localFmt)
        applyClock(views, R.id.digital_utc, "UTC", localFmt)
        views.setTextViewText(R.id.zone_label, zone.replace('_', ' '))

        val utcView = tryFind(views, R.id.utc_row)
        if (utcView) {
            views.setViewVisibility(
                R.id.utc_row,
                if (showUtc) View.VISIBLE else View.GONE,
            )
        }

        val hasTimer = timerMode == "down" || timerMode == "up"
        val hasAlarm = alarmLine.isNotEmpty()
        views.setViewVisibility(
            R.id.event_row,
            if (hasTimer || hasAlarm) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(R.id.timer_chrono, if (hasTimer) View.VISIBLE else View.GONE)
        views.setViewVisibility(
            R.id.timer_name,
            if (hasTimer && timerName.isNotEmpty()) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(R.id.alarm_line, if (hasAlarm) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.timer_name, timerName)
        views.setTextViewText(R.id.alarm_line, alarmLine)

        if (hasTimer && timerAnchorMs > 0L) {
            val remainingOrElapsed = timerAnchorMs - System.currentTimeMillis()
            val base = if (timerMode == "down") {
                SystemClock.elapsedRealtime() + remainingOrElapsed
            } else {
                SystemClock.elapsedRealtime() - (System.currentTimeMillis() - timerAnchorMs)
            }
            views.setChronometer(R.id.timer_chrono, base, null, true)
            views.setChronometerCountDown(R.id.timer_chrono, timerMode == "down")
        } else {
            views.setChronometer(R.id.timer_chrono, SystemClock.elapsedRealtime(), null, false)
        }

        views.setViewVisibility(
            R.id.seconds_row,
            if (widgetSeconds) View.VISIBLE else View.GONE,
        )
        if (widgetSeconds) {
            try {
                views.setString(R.id.seconds_clock, "setTimeZone", zone)
            } catch (_: Exception) {
            }
        }
        return views
    }

    private fun tryFind(views: RemoteViews, id: Int): Boolean {
        return try {
            views.setViewVisibility(id, View.VISIBLE)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun applyClock(
        views: RemoteViews,
        id: Int,
        timeZone: String,
        format: String,
    ) {
        views.setString(id, "setTimeZone", timeZone)
        views.setCharSequence(id, "setFormat12Hour", format)
        views.setCharSequence(id, "setFormat24Hour", format)
    }
}
