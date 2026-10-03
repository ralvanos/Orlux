package com.io.github.com.ralvanos.orlux

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject

object NativeAlerts {
    const val ACTION_FIRE = "com.io.github.com.ralvanos.orlux.FIRE"
    const val ACTION_STOP = "com.io.github.com.ralvanos.orlux.STOP"
    const val ACTION_SNOOZE = "com.io.github.com.ralvanos.orlux.SNOOZE"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_BODY = "body"
    const val EXTRA_LOOP = "loop"
    const val EXTRA_SOUND = "soundPath"
    const val EXTRA_PAYLOAD = "payload"
    const val EXTRA_SNOOZE = "snooze"
    const val EXTRA_CODE = "needsCode"
    const val EXTRA_KIND = "kind"
    const val EXTRA_CRESCENDO = "crescendo"

    private const val PREFS = "orlux_native_alerts"
    private const val KEY_EVENTS = "events"
    private const val KEY_IDS = "ids"
    private const val KEY_PENDING = "pending"

    fun replaceAll(context: Context, events: List<Map<String, Any?>>) {
        cancelStored(context)
        val array = JSONArray()
        val ids = JSONArray()
        for (event in events) {
            val obj = JSONObject()
            val id = (event["id"] as Number).toInt()
            val at = (event["atMs"] as Number).toLong()
            obj.put("id", id)
            obj.put("atMs", at)
            obj.put("title", event["title"] as? String ?: "Orlux")
            obj.put("body", event["body"] as? String ?: "")
            obj.put("loop", event["loop"] as? Boolean ?: true)
            obj.put("soundPath", event["soundPath"] as? String ?: "")
            obj.put("payload", event["payload"] as? String ?: "")
            obj.put("snooze", (event["snooze"] as? Number)?.toInt() ?: 0)
            obj.put("needsCode", event["needsCode"] as? Boolean ?: false)
            obj.put("kind", event["kind"] as? String ?: "alarm")
            obj.put("crescendo", event["crescendo"] as? Boolean ?: true)
            array.put(obj)
            ids.put(id)
            if (at > System.currentTimeMillis()) {
                schedule(context, obj)
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_EVENTS, array.toString())
            .putString(KEY_IDS, ids.toString())
            .apply()
    }

    fun rescheduleFromPrefs(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_EVENTS, "[]") ?: "[]"
        val array = JSONArray(raw)
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            if (obj.optLong("atMs") > System.currentTimeMillis()) {
                schedule(context, obj)
            }
        }
    }

    fun stop(context: Context) {
        AlertService.stop(context)
    }

    fun stashPending(context: Context, payload: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString(KEY_PENDING, payload)
            .apply()
    }

    fun takePending(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val value = prefs.getString(KEY_PENDING, null)
        prefs.edit().remove(KEY_PENDING).apply()
        return value
    }

    fun snoozeFromIntent(context: Context, intent: Intent) {
        val minutes = intent.getIntExtra(EXTRA_SNOOZE, 0)
        if (minutes < 1) {
            stop(context)
            return
        }
        val at = System.currentTimeMillis() + minutes * 60_000L
        val obj = JSONObject()
        obj.put("id", intent.getIntExtra(EXTRA_ID, 0))
        obj.put("atMs", at)
        obj.put("title", intent.getStringExtra(EXTRA_TITLE) ?: "Orlux")
        obj.put("body", intent.getStringExtra(EXTRA_BODY) ?: "Snoozed")
        obj.put("loop", true)
        obj.put("soundPath", intent.getStringExtra(EXTRA_SOUND) ?: "")
        obj.put("payload", intent.getStringExtra(EXTRA_PAYLOAD) ?: "")
        obj.put("snooze", minutes)
        obj.put("needsCode", intent.getBooleanExtra(EXTRA_CODE, false))
        obj.put("kind", intent.getStringExtra(EXTRA_KIND) ?: "alarm")
        stop(context)
        schedule(context, obj)
    }

    private fun schedule(context: Context, obj: JSONObject) {
        val id = obj.getInt("id")
        val at = obj.getLong("atMs")
        val fire = Intent(context, AlertReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, obj.optString("title"))
            putExtra(EXTRA_BODY, obj.optString("body"))
            putExtra(EXTRA_LOOP, obj.optBoolean("loop", true))
            putExtra(EXTRA_SOUND, obj.optString("soundPath"))
            putExtra(EXTRA_PAYLOAD, obj.optString("payload"))
            putExtra(EXTRA_SNOOZE, obj.optInt("snooze"))
            putExtra(EXTRA_CODE, obj.optBoolean("needsCode"))
            putExtra(EXTRA_KIND, obj.optString("kind"))
            putExtra(EXTRA_CRESCENDO, obj.optBoolean("crescendo", true))
        }
        val firePi = PendingIntent.getBroadcast(
            context,
            id,
            fire,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val show = PendingIntent.getActivity(
            context,
            id,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_PAYLOAD, obj.optString("payload"))
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val kind = obj.optString("kind")
        try {
            if (kind == "bedtime") {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, firePi)
            } else {
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), firePi)
            }
        } catch (_: Exception) {
            manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, firePi)
        }
    }

    private fun cancelStored(context: Context) {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_IDS, "[]") ?: "[]"
        val ids = JSONArray(raw)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (i in 0 until ids.length()) {
            val id = ids.getInt(i)
            val fire = Intent(context, AlertReceiver::class.java).apply {
                action = ACTION_FIRE
            }
            val pi = PendingIntent.getBroadcast(
                context,
                id,
                fire,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            manager.cancel(pi)
        }
    }
}
