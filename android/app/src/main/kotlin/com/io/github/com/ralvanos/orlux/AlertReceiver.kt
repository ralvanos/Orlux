package com.io.github.com.ralvanos.orlux

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            NativeAlerts.ACTION_FIRE -> {
                if (intent.getStringExtra(NativeAlerts.EXTRA_KIND) == "bedtime") {
                    BedtimeNotifier.show(context, intent)
                } else {
                    AlertService.start(context, intent)
                }
            }
            NativeAlerts.ACTION_STOP -> {
                NativeAlerts.stashPending(context, """{"k":"dismiss"}""")
                AlertService.stop(context)
            }
            NativeAlerts.ACTION_SNOOZE -> NativeAlerts.snoozeFromIntent(context, intent)
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" ->
                NativeAlerts.rescheduleFromPrefs(context)
        }
    }
}
