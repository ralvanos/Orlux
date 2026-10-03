package com.io.github.com.ralvanos.orlux

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var alertsChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orlux/widget")
            .setMethodCallHandler { call, result ->
                if (call.method != "update") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val args = call.arguments as? Map<*, *>
                WidgetStore.saveConfig(
                    this,
                    timezone = args?.get("timezone") as? String ?: "UTC",
                    use24Hour = args?.get("use24Hour") as? Boolean ?: true,
                    showUtc = args?.get("showUtc") as? Boolean ?: true,
                    timerName = args?.get("timerName") as? String ?: "",
                    timerMode = args?.get("timerMode") as? String ?: "none",
                    timerAnchorMs = (args?.get("timerAnchorMs") as? Number)?.toLong() ?: 0L,
                    alarmLine = args?.get("alarmLine") as? String ?: "",
                    widgetSeconds = args?.get("widgetSeconds") as? Boolean ?: true,
                )
                WidgetStore.refreshAll(this)
                result.success(null)
            }

        alertsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "orlux/alerts")
        alertsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "replaceAll" -> {
                    val raw = call.arguments as? List<*> ?: emptyList<Any>()
                    val events = raw.mapNotNull { item ->
                        val map = item as? Map<*, *> ?: return@mapNotNull null
                        map.entries.associate { it.key.toString() to it.value }
                    }
                    NativeAlerts.replaceAll(this, events)
                    result.success(null)
                }
                "stop" -> {
                    NativeAlerts.stop(this)
                    result.success(null)
                }
                "snooze" -> {
                    val args = call.arguments as? Map<*, *>
                    val intent = Intent().apply {
                        putExtra(NativeAlerts.EXTRA_ID, (args?.get("id") as? Number)?.toInt() ?: 0)
                        putExtra(NativeAlerts.EXTRA_SNOOZE, (args?.get("minutes") as? Number)?.toInt() ?: 0)
                        putExtra(NativeAlerts.EXTRA_TITLE, args?.get("title") as? String ?: "Orlux")
                        putExtra(NativeAlerts.EXTRA_BODY, args?.get("body") as? String ?: "")
                        putExtra(NativeAlerts.EXTRA_PAYLOAD, args?.get("payload") as? String ?: "")
                        putExtra(NativeAlerts.EXTRA_CODE, args?.get("needsCode") as? Boolean ?: false)
                        putExtra(NativeAlerts.EXTRA_KIND, "alarm")
                    }
                    NativeAlerts.snoozeFromIntent(this, intent)
                    result.success(null)
                }
                "takePending" -> result.success(NativeAlerts.takePending(this))
                "requestBattery" -> {
                    requestBatteryExemption()
                    result.success(null)
                }
                "batteryExempt" -> result.success(isBatteryExempt())
                else -> result.notImplemented()
            }
        }
        deliverPending()
    }

    override fun onResume() {
        super.onResume()
        deliverPending()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = intent.getStringExtra(NativeAlerts.EXTRA_PAYLOAD)
        if (!payload.isNullOrEmpty()) {
            NativeAlerts.stashPending(this, payload)
        }
        deliverPending()
    }

    private fun deliverPending() {
        val payload = NativeAlerts.takePending(this)
        if (!payload.isNullOrEmpty()) {
            alertsChannel?.invokeMethod("fired", payload)
        }
    }

    private fun isBatteryExempt(): Boolean {
        val pm = getSystemService(PowerManager::class.java)
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestBatteryExemption() {
        if (isBatteryExempt()) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
}
