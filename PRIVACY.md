# Privacy Policy

**Orlux** is a standalone, offline Android clock (watch face, timers, alarms, sleep hours). Package `com.io.github.com.ralvanos.orlux`.

Last updated: 23 September 2026

## Data collection

Orlux does **not** collect, transmit, or share personal data. There are no analytics, crash reporters, advertising SDKs, accounts, or backend APIs. Nothing in the app is uploaded to the developer or to a third-party service.

## Data storage

All data stays on your device:

- Timezone, clock face, night dim, sounds, and other settings
- Stopwatches, countdowns, and alarm times (including skip-today and holiday skip)
- Sleep nights you log (bedtime, wake time, hours, whether the alarm was skipped)
- Optional custom alert sounds you import
- Optional app PIN (stored as a salted hash only)
- Exported backup files, only when you choose to save them

Home-screen widgets read the same on-device clock and timer/alarm summary so the launcher can draw them. Widget text does not leave the device.

**On-device encryption:** User data is encrypted at rest (AES-CBC). The key is kept in Android Keystore-backed storage.

**Exports:** Settings → Export. Optional PIN-protect. A plaintext file is not protected once you save it elsewhere.

## Network access

The **release** app does not declare the `INTERNET` permission and does not make HTTP requests. Debug/profile builds include internet permission only for Flutter tooling.

Optional **Send feedback** opens your email app with `ralvanos@protonmail.com`. Orlux does not send the message itself.

## Notifications and ringing

Alarms, bedtime reminders, and finished countdowns use **local** notifications and a **local** foreground media-playback service on this device. Stop and snooze run on the device. There is no remote push.

## Permissions

Used only for the features named:

- Notifications — alarms, timers, bedtime reminder
- Boot completed / package replaced — reschedule after restart or update
- Vibrate / wake lock / turn screen on — haptics, keep-awake, alarm wake
- Exact alarms / full-screen intent — fire on time, including when the app is closed
- Foreground service (media playback) — play the alarm or timer tone
- Ignore battery optimizations — optional; improves closed-app reliability if you grant it
- File access via the system picker — only when you import or export a backup or a custom sound

Orlux does not use location, contacts, microphone, camera, health sensors, or wearable APIs. Sleep tracking is hours between **Going to bed** / **I’m up** (or stopping the alarm), not biometric monitoring.

## Contact

[ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)
