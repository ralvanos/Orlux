# Orlux

**Version:** 1.1.0+2  
**Package:** `com.io.github.com.ralvanos.orlux`  
**Platform:** Android only

An **offline** clock. Orlux shows UTC and a timezone you choose, then adds stopwatches, countdowns, alarms, home-screen widgets, and optional sleep hours. No accounts, no ads, no wearables. Data stays on the device and is encrypted at rest.

## Features

* **Dual clock** — local timezone plus UTC; analog, digital, or hybrid; optional night dim
* **Keep-awake** and optional **PIN lock** so the face is not a pocket toy
* **Stopwatches** — start / stop / reset, laps, delayed start, several at once
* **Countdowns** — same controls; optional chain so one timer starts the next; per-timer sound
* **Alarms** — named times, repeat days, local or UTC, snooze, skip today, skip US federal holidays, per-alarm sound, optional wake code to stop
* **Closed-app alerts** — native `AlarmManager` plus a foreground service so timers and alarms still ring when Orlux is not open; Stop on the overlay or notification ends the tone
* **Home-screen widgets** — compact watch and a larger 4×4 face (time is not animated second-by-second)
* **Sleep hours** — turn on track sleep, tap **Going to bed**, then **I’m up**. **I’m up** logs the night, turns off every alarm still set for that day, and marks the night skipped. Edit a night from the latest week with a fell-asleep and woke time, and add another stretch if you were awake in the middle. The chart keeps every saved night; the average uses the last 14
* **Bedtime reminder**, optional volume crescendo, haptics, and click sounds
* **On-device encryption** and import / export JSON (optional PIN-protect on export)

## Setup

Requires [Flutter](https://flutter.dev) 3 (Dart 3).

```bash
flutter pub get
flutter test
flutter run
```

Release APK:

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk` (gitignored). The version name and Android version code come from `pubspec.yaml` (`1.1.0+2`).

Release signing uses `android/key.properties` and a keystore file such as `android/app/orlux.jks`. Both are gitignored. Copy `android/key.properties.example` to `android/key.properties` and fill in your own store. Debug builds work without it.

## Tested on

1.1.0 was tested on:

- Samsung Galaxy S23
- Google Pixel 8

## Privacy

See [PRIVACY.md](PRIVACY.md). Release builds do not request internet permission.

## Feedback & Support

Questions, ideas, or bug reports are always welcome.

- **Email**: [ralvanos@protonmail.com](mailto:ralvanos@protonmail.com)

### Support the App

Orlux is designed to be fully free and ad-free. Donations are completely voluntary. If you contribute and would like recognition, I'll gladly find a way to feature your name.

> "Doubt kills more dreams than failure ever will" - Suzy Kassem

#### Voluntary donations

- **Bitcoin**: `bc1qm0pwaxjyd809v7d606duklmcujn9sygnkgyunx`
- **Monero**: `82sVJnuXRSRGv8RnZGPhpQYssmSAQXT8aXu81CB9iifMB73HKmuMcGNWxmV5s8ELUoaHtJeY13akB7m5f6DMjCDW1mFjtKV`

## License

MIT — see [LICENSE](LICENSE).
