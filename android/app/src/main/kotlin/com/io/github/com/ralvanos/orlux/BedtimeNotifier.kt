package com.io.github.com.ralvanos.orlux

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat

object BedtimeNotifier {
    private const val CHANNEL = "orlux_bedtime"
    private const val ID = 43

    fun show(context: Context, source: Intent) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                "Bedtime",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
        val open = PendingIntent.getActivity(
            context,
            8,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(source.getStringExtra(NativeAlerts.EXTRA_TITLE) ?: "Time for bed")
            .setContentText(
                source.getStringExtra(NativeAlerts.EXTRA_BODY)
                    ?: "Mark Going to bed to start tonight’s sleep log.",
            )
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(ID, notification)
    }
}
