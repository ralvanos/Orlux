package com.io.github.com.ralvanos.orlux

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import java.io.File

class AlertService : Service() {
    private val ramp = Handler(Looper.getMainLooper())
    private var volume = 0.12f
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == NativeAlerts.ACTION_STOP || intent == null) {
            shutdown()
            stopSelf()
            return START_NOT_STICKY
        }
        val title = intent.getStringExtra(NativeAlerts.EXTRA_TITLE) ?: "Orlux"
        val body = intent.getStringExtra(NativeAlerts.EXTRA_BODY) ?: ""
        val payload = intent.getStringExtra(NativeAlerts.EXTRA_PAYLOAD) ?: ""
        val loop = intent.getBooleanExtra(NativeAlerts.EXTRA_LOOP, true)
        val soundPath = intent.getStringExtra(NativeAlerts.EXTRA_SOUND) ?: ""
        val snooze = intent.getIntExtra(NativeAlerts.EXTRA_SNOOZE, 0)
        val needsCode = intent.getBooleanExtra(NativeAlerts.EXTRA_CODE, false)
        val crescendo = intent.getBooleanExtra(NativeAlerts.EXTRA_CRESCENDO, true)

        if (payload.isNotEmpty()) {
            NativeAlerts.stashPending(this, payload)
        }

        ensureChannel()
        startForeground(NOTIF_ID, buildNotification(title, body, intent, snooze, needsCode))
        acquireWakeLock()
        startSound(soundPath, loop, crescendo)
        startVibrate(loop)
        openApp(payload)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }

    private fun shutdown() {
        ramp.removeCallbacksAndMessages(null)
        haltAudio()
        haltVibrate()
        releaseFocus()
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        getSystemService(NotificationManager::class.java).cancel(NOTIF_ID)
    }

    private fun ensureChannel() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL,
                "Alarms and timers",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                setSound(null, null)
                enableVibration(true)
                setBypassDnd(true)
            },
        )
    }

    private fun buildNotification(
        title: String,
        body: String,
        source: Intent,
        snooze: Int,
        needsCode: Boolean,
    ): Notification {
        val open = PendingIntent.getActivity(
            this,
            2,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(
                    NativeAlerts.EXTRA_PAYLOAD,
                    source.getStringExtra(NativeAlerts.EXTRA_PAYLOAD),
                )
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stop = PendingIntent.getBroadcast(
            this,
            3,
            Intent(this, AlertReceiver::class.java).setAction(NativeAlerts.ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(if (needsCode) "$body · Open Orlux to stop" else body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setContentIntent(open)
            .setDeleteIntent(stop)
            .setFullScreenIntent(open, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        builder.addAction(0, if (needsCode) "Open to stop" else "Stop", if (needsCode) open else stop)
        if (snooze > 0) {
            val snoozeIntent = Intent(this, AlertReceiver::class.java).apply {
                action = NativeAlerts.ACTION_SNOOZE
                putExtras(source)
            }
            val snoozePi = PendingIntent.getBroadcast(
                this,
                4,
                snoozeIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            builder.addAction(0, "Snooze ${snooze}m", snoozePi)
        }
        return builder.build()
    }

    private fun startSound(soundPath: String, loop: Boolean, crescendo: Boolean) {
        haltAudio()
        requestFocus()
        try {
            val media = MediaPlayer()
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            media.setAudioAttributes(attrs)
            val file = File(soundPath)
            if (soundPath.isNotEmpty() && file.exists()) {
                media.setDataSource(file.absolutePath)
            } else {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                media.setDataSource(this, uri)
            }
            media.isLooping = loop
            media.prepare()
            volume = if (loop && crescendo) 0.12f else 1f
            media.setVolume(volume, volume)
            if (!loop) {
                media.setOnCompletionListener {
                    haltAudio()
                    haltVibrate()
                    stopSelf()
                }
            }
            media.start()
            player = media
            if (loop && crescendo) rampVolume()
        } catch (_: Exception) {
            try {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                val tone = RingtoneManager.getRingtone(this, uri)
                if (Build.VERSION.SDK_INT >= 28) {
                    tone.isLooping = loop
                    tone.audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .build()
                }
                tone.play()
                ringtone = tone
            } catch (_: Exception) {
            }
        }
    }

    private fun rampVolume() {
        volume = (volume + 0.1f).coerceAtMost(1f)
        try {
            player?.setVolume(volume, volume)
        } catch (_: Exception) {
        }
        if (volume < 1f) {
            ramp.postDelayed({ rampVolume() }, 1500)
        }
    }

    private fun startVibrate(loop: Boolean) {
        try {
            vibrator = if (Build.VERSION.SDK_INT >= 31) {
                getSystemService(VibratorManager::class.java).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Vibrator::class.java)
            }
            if (loop) {
                vibrator?.vibrate(
                    VibrationEffect.createWaveform(longArrayOf(0, 600, 400, 600), 0),
                )
            } else {
                vibrator?.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
            }
        } catch (_: Exception) {
        }
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(PowerManager::class.java)
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "orlux:alert",
        ).apply { acquire(10 * 60 * 1000L) }
    }

    private fun openApp(payload: String) {
        val launch = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(NativeAlerts.EXTRA_PAYLOAD, payload)
        }
        try {
            startActivity(launch)
        } catch (_: Exception) {
        }
    }

    private fun requestFocus() {
        try {
            val am = getSystemService(AudioManager::class.java)
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            focusRequest = request
            am.requestAudioFocus(request)
        } catch (_: Exception) {
        }
    }

    private fun releaseFocus() {
        try {
            val request = focusRequest ?: return
            getSystemService(AudioManager::class.java).abandonAudioFocusRequest(request)
        } catch (_: Exception) {
        }
        focusRequest = null
    }

    companion object {
        private const val CHANNEL = "orlux_native_alert"
        private const val NOTIF_ID = 42
        private var player: MediaPlayer? = null
        private var ringtone: Ringtone? = null
        private var vibrator: Vibrator? = null

        fun start(context: Context, source: Intent) {
            val intent = Intent(context, AlertService::class.java).apply {
                putExtras(source)
            }
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            haltAudio()
            haltVibrate()
            context.stopService(Intent(context, AlertService::class.java))
            context.getSystemService(NotificationManager::class.java).cancel(NOTIF_ID)
        }

        private fun haltAudio() {
            try {
                player?.stop()
            } catch (_: Exception) {
            }
            try {
                player?.release()
            } catch (_: Exception) {
            }
            player = null
            try {
                ringtone?.stop()
            } catch (_: Exception) {
            }
            ringtone = null
        }

        private fun haltVibrate() {
            try {
                vibrator?.cancel()
            } catch (_: Exception) {
            }
            vibrator = null
        }
    }
}
