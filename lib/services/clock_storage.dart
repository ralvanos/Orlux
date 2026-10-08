import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/clock_alarm.dart';
import '../models/clock_math.dart';
import '../models/clock_settings.dart';
import '../models/clock_sound.dart';
import '../models/clock_timer.dart';
import '../models/export_schema.dart';
import '../models/federal_holidays.dart';
import '../models/sleep_night.dart';
import 'alarm_ring.dart';
import 'auto_lock_policy.dart';
import 'encrypted_store.dart';
import 'export_crypto.dart';
import 'native_alerts.dart';
import 'sound_service.dart';
import 'timer_ring.dart';
import 'watch_widget_sync.dart';

class ImportResult {
  const ImportResult.success(this.data)
      : success = true,
        needsPassphrase = false,
        encryptedEnvelope = null,
        errorMessage = null;

  const ImportResult.needsPassphrase(this.encryptedEnvelope)
      : success = false,
        needsPassphrase = true,
        data = null,
        errorMessage = null;

  const ImportResult.failure(this.errorMessage)
      : success = false,
        needsPassphrase = false,
        encryptedEnvelope = null,
        data = null;

  final bool success;
  final bool needsPassphrase;
  final String? errorMessage;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? encryptedEnvelope;
}

enum ExportResult { success, cancelled, failure }

class ClockStorage {
  ClockStorage._();

  static const keyTimezone = 'timezone';
  static const keyDisplayMode = 'display_mode';
  static const keyHaptics = 'haptics';
  static const keySound = 'sound';
  static const keyKeepAwake = 'keep_awake';
  static const keyAutoLock = 'auto_lock_timeout_seconds';
  static const keyAlertSound = 'alert_sound_id';
  static const keyUse24Hour = 'use_24_hour';
  static const keyShowUtc = 'show_utc';
  static const keyNightDim = 'night_dim_mode';
  static const keyStatusBar = 'status_bar_notifications';
  static const keyCrescendo = 'crescendo';
  static const keyBedtimeReminder = 'bedtime_reminder';
  static const keySleepGoal = 'sleep_goal_minutes';
  static const keyWidgetSeconds = 'widget_seconds';
  static const keyTimers = 'timers';
  static const keyAlarms = 'alarms';
  static const keySleepNights = 'sleep_nights';
  static const keyBedtimeMs = 'sleep_bedtime_ms';

  static const actionSnooze = 'orlux_snooze';
  static const actionStop = 'orlux_stop';
  static const actionSkipToday = 'orlux_skip_today';
  static const _bedtimeIdBase = 31000;
  static const _channelAlarms = 'orlux_alarms3';
  static const _channelTimers = 'orlux_cdown';
  static const _channelDelay = 'orlux_delay2';
  static const _channelSnooze = 'orlux_snooze2';
  static const _channelTimerLive = 'orlux_cdown_now';
  static const _channelStatus = 'orlux_on_now';
  static const _alarmIdBase = 1000;
  static const _timerIdBase = 5000;
  static const _delayIdBase = 9000;
  static const _snoozeIdBase = 13000;
  static const _timerLiveIdBase = 17000;
  static const _alarmLiveIdBase = 21000;
  static const _timerStatusIdBase = 25000;
  static const _nextAlarmStatusId = 28999;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static EncryptedStore get _store => EncryptedStore.instance;
  static bool notificationsPermissionGranted = true;
  static bool _initialized = false;
  static bool _settlingAlarms = false;
  static final Map<String, String> _firedAlarmMinutes = {};
  static Timer? _alarmRingStop;
  static final Set<int> _shownTimerStatusIds = {};
  static final ValueNotifier<int> sleepRevision = ValueNotifier<int>(0);

  static String newId() {
    final rng = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-${rng.nextInt(1 << 32)}';
  }

  static int _snoozeNotifId(String alarmId) =>
      _snoozeIdBase + (alarmId.hashCode.abs() % 4000);

  static int _liveAlarmNotifId(String alarmId) =>
      _alarmLiveIdBase + (alarmId.hashCode.abs() % 4000);

  static int _timerStatusId(String timerId) =>
      _timerStatusIdBase + (timerId.hashCode.abs() % 4000);

  static String _alarmPayloadJson(ClockAlarm alarm) => jsonEncode({
        'k': 'alarm',
        'id': alarm.id,
        'snooze': alarm.snoozeMinutes,
        'label': alarm.label,
        'sound': alarm.soundId,
        'hour': alarm.hour,
        'minute': alarm.minute,
        'utc': alarm.useUtc,
        'wakeCode': alarm.wakeCode,
        'trackSleep': alarm.trackSleep,
      });

  static List<AndroidNotificationAction> _alarmActions(int snoozeMinutes) {
    return [
      const AndroidNotificationAction(
        actionStop,
        'Stop',
        cancelNotification: true,
        showsUserInterface: true,
      ),
      if (snoozeMinutes > 0)
        const AndroidNotificationAction(
          actionSnooze,
          'Snooze',
          cancelNotification: true,
          showsUserInterface: true,
        ),
    ];
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await EncryptedStore.instance.ensureInitialized();
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      final saved = await _store.getString(keyTimezone);
      if (saved == null || saved.isEmpty) {
        await _store.setString(keyTimezone, name);
      }
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          orluxNotificationTapBackground,
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelAlarms,
        'Alarms',
        description: 'Orlux alarm times',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelTimers,
        'Timers',
        description: 'Countdown finished',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelSnooze,
        'Snooze',
        description: 'Snoozed alarms',
        importance: Importance.max,
        playSound: true,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelStatus,
        'On now',
        description: 'Running timers and upcoming alarms',
        importance: Importance.low,
        playSound: false,
        showBadge: false,
      ),
    );
    final granted = await android?.requestNotificationsPermission();
    notificationsPermissionGranted = granted ?? true;
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
    NativeAlerts.channel.setMethodCallHandler((call) async {
      if (call.method == 'fired') {
        await handleNativeFire(call.arguments as String?);
      }
    });
    await rescheduleAll();
    await handleNativeFire(await NativeAlerts.takePending());
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    await init();
    final payload = response.payload;
    Map<String, dynamic>? data;
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (response.actionId == actionStop) {
      await stopRingingAlarm();
      return;
    }
    if (response.actionId == actionSnooze) {
      final ringing = _alarmFromPayload(data);
      if (ringing != null) AlarmRing.instance.show(ringing);
      await snoozeRingingAlarm();
      return;
    }
    if (response.actionId == actionSkipToday) {
      final ringing = _alarmFromPayload(data);
      if (ringing != null) {
        final stored = (await getAlarms())
            .where((a) => a.id == ringing.id)
            .toList();
        await skipToday(stored.isEmpty ? ringing : stored.first);
      }
      return;
    }
    if (data != null && data['k'] == 'alarm') {
      final ringing = _alarmFromPayload(data);
      if (ringing != null) {
        AlarmRing.instance.show(ringing);
      }
      await rescheduleAlarms(await getAlarms());
    }
  }

  static ClockAlarm? _alarmFromPayload(Map<String, dynamic>? data) {
    if (data == null) return AlarmRing.instance.ringing.value;
    final id = data['id'] as String? ?? '';
    if (id.isEmpty) return AlarmRing.instance.ringing.value;
    return ClockAlarm(
      id: id,
      label: data['label'] as String? ?? 'Alarm',
      hour: (data['hour'] as num?)?.toInt() ?? 0,
      minute: (data['minute'] as num?)?.toInt() ?? 0,
      snoozeMinutes: (data['snooze'] as num?)?.toInt() ?? 0,
      soundId: data['sound'] as String?,
      useUtc: data['utc'] == true,
      wakeCode: data['wakeCode'] == true,
      trackSleep: data['trackSleep'] == true,
    );
  }

  static Future<void> scheduleSnooze({
    required String alarmId,
    required int minutes,
    required String label,
    String? soundId,
    int hour = 0,
    int minute = 0,
    bool useUtc = false,
  }) async {
    if (minutes < 1) return;
    final when = tz.TZDateTime.now(tz.UTC).add(Duration(minutes: minutes));
    final details = await _alertDetails(
      baseChannel: _channelSnooze,
      name: 'Snooze',
      description: 'Snoozed alarms',
      importance: Importance.max,
      priority: Priority.max,
      usage: AudioAttributesUsage.alarm,
      soundId: soundId,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      actions: _alarmActions(minutes),
    );
    await _notifications.zonedSchedule(
      id: _snoozeNotifId(alarmId),
      title: label,
      body: 'Snoozed · again in $minutes min',
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({
        'k': 'alarm',
        'id': alarmId,
        'snooze': minutes,
        'label': label,
        'sound': soundId,
        'hour': hour,
        'minute': minute,
        'utc': useUtc,
      }),
    );
  }

  static Future<ClockSettings> getSettings() async {
    final modeName = await _store.getString(keyDisplayMode) ?? '';
    final dimName = await _store.getString(keyNightDim) ?? '';
    return ClockSettings(
      timezone: await _store.getString(keyTimezone) ?? 'UTC',
      displayMode: DisplayMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => DisplayMode.hybrid,
      ),
      haptics: await _store.getBool(keyHaptics) ?? true,
      sound: await _store.getBool(keySound) ?? true,
      keepAwake: await _store.getBool(keyKeepAwake) ?? true,
      autoLockTimeoutSeconds: AutoLockPolicy.normalizeTimeout(
        await _store.getInt(keyAutoLock),
      ),
      alertSoundId: SoundCatalog.resolve(
        await _store.getString(keyAlertSound),
      ),
      use24Hour: await _store.getBool(keyUse24Hour) ?? true,
      showUtc: await _store.getBool(keyShowUtc) ?? true,
      nightDimMode: NightDimMode.values.firstWhere(
        (m) => m.name == dimName,
        orElse: () => NightDimMode.off,
      ),
      showStatusNotifications: await _store.getBool(keyStatusBar) ?? true,
      crescendo: await _store.getBool(keyCrescendo) ?? true,
      bedtimeReminder: await _store.getBool(keyBedtimeReminder) ?? true,
      sleepGoalMinutes: await _store.getInt(keySleepGoal) ?? 450,
      widgetSeconds: await _store.getBool(keyWidgetSeconds) ?? true,
    );
  }

  static Future<void> saveSettings(ClockSettings settings) async {
    await _store.setString(keyTimezone, settings.timezone);
    await _store.setString(keyDisplayMode, settings.displayMode.name);
    await _store.setBool(keyHaptics, settings.haptics);
    await _store.setBool(keySound, settings.sound);
    await _store.setBool(keyKeepAwake, settings.keepAwake);
    await _store.setInt(keyAutoLock, settings.autoLockTimeoutSeconds);
    await _store.setString(keyAlertSound, settings.alertSoundId);
    await _store.setBool(keyUse24Hour, settings.use24Hour);
    await _store.setBool(keyShowUtc, settings.showUtc);
    await _store.setString(keyNightDim, settings.nightDimMode.name);
    await _store.setBool(keyStatusBar, settings.showStatusNotifications);
    await _store.setBool(keyCrescendo, settings.crescendo);
    await _store.setBool(keyBedtimeReminder, settings.bedtimeReminder);
    await _store.setInt(keySleepGoal, settings.sleepGoalMinutes);
    await _store.setBool(keyWidgetSeconds, settings.widgetSeconds);
    await rescheduleAll();
  }

  static Future<int> getAutoLockTimeoutSeconds() async {
    return (await getSettings()).autoLockTimeoutSeconds;
  }

  static Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    final settings = await getSettings();
    await saveSettings(
      settings.copyWith(autoLockTimeoutSeconds: seconds),
    );
  }

  static tz.Location locationFor(ClockSettings settings) {
    try {
      return tz.getLocation(settings.timezone);
    } catch (_) {
      return tz.UTC;
    }
  }

  static DateTime wallNow(ClockSettings settings, [DateTime? utc]) {
    final instant = (utc ?? DateTime.now()).toUtc();
    final loc = locationFor(settings);
    final zoned = tz.TZDateTime.from(instant, loc);
    return DateTime(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
      zoned.second,
      zoned.millisecond,
    );
  }

  static Future<List<ClockTimer>> getTimers() async {
    final raw = await _store.getString(keyTimers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ClockTimer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTimers(List<ClockTimer> timers) async {
    await _store.setString(
      keyTimers,
      jsonEncode(timers.map((t) => t.toJson()).toList()),
    );
    await rescheduleTimers(timers);
    await _syncHomeWidget(timers: timers);
  }

  static Future<ClockTimer> upsertTimer(ClockTimer timer) async {
    final timers = await getTimers();
    final index = timers.indexWhere((t) => t.id == timer.id);
    if (index >= 0) {
      timers[index] = timer;
    } else {
      timers.add(timer);
    }
    await saveTimers(timers);
    return timer;
  }

  static Future<void> deleteTimer(String id) async {
    final timers = await getTimers();
    timers.removeWhere((t) => t.id == id);
    for (var i = 0; i < timers.length; i++) {
      if (timers[i].onCompleteStartId == id) {
        timers[i] = timers[i].copyWith(clearChain: true);
      }
    }
    await saveTimers(timers);
  }

  static Future<ClockTimer> startTimer(ClockTimer timer, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    if (timer.isDelaying(clock)) return timer;
    var next = timer;
    if (timer.delaySeconds > 0 && !timer.isRunning && timer.delayUntil == null) {
      next = timer.copyWith(
        delayUntil: clock.add(Duration(seconds: timer.delaySeconds)),
      );
      await upsertTimer(next);
      await _feedback();
      return next;
    }
    if (timer.isCountdown && timer.elapsedMs(clock) >= timer.durationMs) {
      next = timer.copyWith(accumulatedMs: 0, clearRunning: true);
    }
    next = next.copyWith(runningSince: clock, clearDelayUntil: true);
    await upsertTimer(next);
    await _feedback();
    return next;
  }

  static Future<ClockTimer> stopTimer(ClockTimer timer, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    if (timer.isDelaying(clock)) {
      final next = timer.copyWith(clearDelayUntil: true);
      await upsertTimer(next);
      await _feedback();
      return next;
    }
    final elapsed = timer.elapsedMs(clock);
    final next = timer.copyWith(
      accumulatedMs: timer.isCountdown
          ? min(elapsed, timer.durationMs)
          : elapsed,
      clearRunning: true,
      clearDelayUntil: true,
    );
    await upsertTimer(next);
    await _feedback();
    return next;
  }

  static Future<ClockTimer> resetTimer(ClockTimer timer) async {
    final next = timer.copyWith(
      accumulatedMs: 0,
      clearRunning: true,
      laps: const [],
      clearDelayUntil: true,
    );
    await upsertTimer(next);
    await _feedback();
    return next;
  }

  static Future<ClockTimer> lapTimer(ClockTimer timer, {DateTime? now}) async {
    if (timer.kind != TimerKind.stopwatch) return timer;
    final elapsed = timer.elapsedMs(now);
    final next = timer.copyWith(laps: [...timer.laps, elapsed]);
    await upsertTimer(next);
    await _feedback();
    return next;
  }

  static bool _settling = false;

  static Future<List<ClockTimer>> settleCompleted({DateTime? now}) async {
    if (_settling) return getTimers();
    _settling = true;
    try {
      return await _settleCompleted(now: now);
    } finally {
      _settling = false;
    }
  }

  static Future<List<ClockTimer>> _settleCompleted({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final timers = await getTimers();
    var changed = false;
    final out = <ClockTimer>[];
    final toStart = <String>[];
    final delayEnded = <ClockTimer>[];
    final finished = <ClockTimer>[];
    for (final timer in timers) {
      var current = timer;
      final promoted = timer.promoteDelay(clock);
      if (promoted != null) {
        current = promoted;
        delayEnded.add(promoted);
        changed = true;
      }
      if (current.isCountdown &&
          current.isRunning &&
          current.elapsedMs(clock) >= current.durationMs) {
        current = current.copyWith(
          accumulatedMs: current.durationMs,
          clearRunning: true,
        );
        changed = true;
        finished.add(current);
        if (current.onCompleteStartId != null) {
          toStart.add(current.onCompleteStartId!);
        }
      }
      out.add(current);
    }
    for (final id in toStart) {
      final index = out.indexWhere((t) => t.id == id);
      if (index < 0) continue;
      if (!out[index].isRunning) {
        out[index] = out[index].copyWith(runningSince: clock, accumulatedMs: 0);
        changed = true;
      }
    }
    if (changed) await saveTimers(out);
    for (final timer in delayEnded) {
      if (timer.alertOnDelayEnd) {
        await _onDelayEnded(timer);
      }
    }
    for (final timer in finished) {
      await _onTimerFinished(timer);
    }
    return out;
  }

  static Future<List<ClockAlarm>> getAlarms() async {
    final raw = await _store.getString(keyAlarms);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ClockAlarm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAlarms(List<ClockAlarm> alarms) async {
    await _store.setString(
      keyAlarms,
      jsonEncode(alarms.map((a) => a.toJson()).toList()),
    );
    await rescheduleAlarms(alarms);
    await _syncHomeWidget(alarms: alarms);
  }

  static Future<ClockAlarm> upsertAlarm(ClockAlarm alarm) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((a) => a.id == alarm.id);
    if (index >= 0) {
      alarms[index] = alarm;
    } else {
      alarms.add(alarm);
    }
    await saveAlarms(alarms);
    if (!alarm.enabled || alarm.snoozeMinutes < 1) {
      await _notifications.cancel(id: _snoozeNotifId(alarm.id));
    }
    return alarm;
  }

  static Future<void> deleteAlarm(String id) async {
    final alarms = await getAlarms();
    alarms.removeWhere((a) => a.id == id);
    await saveAlarms(alarms);
    await _notifications.cancel(id: _snoozeNotifId(id));
  }

  static Future<void> _feedback() async {
    final settings = await getSettings();
    if (settings.haptics) {
      await HapticFeedback.mediumImpact();
    }
    if (settings.sound) {
      await SoundService.instance.playClick(enabled: true);
    }
  }

  static Future<void> _onDelayEnded(ClockTimer timer) async {
    await _playTimerAlert(timer);
  }

  static Future<void> _onTimerFinished(ClockTimer timer) async {
    TimerRing.instance.show(timer.name);
    await _playTimerAlert(timer);
    try {
      final details = await _alertDetails(
        baseChannel: _channelTimerLive,
        name: 'Countdown finished',
        description: 'Played when a countdown ends',
        importance: Importance.max,
        priority: Priority.max,
        usage: AudioAttributesUsage.alarm,
        soundId: timer.soundId,
      );
      await _notifications.show(
        id: _timerLiveIdBase + (timer.id.hashCode.abs() % 4000),
        title: timer.name,
        body: 'Countdown finished',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Countdown alert skipped: $e');
    }
  }

  static Future<void> _playTimerAlert(ClockTimer timer) async {
    final settings = await getSettings();
    if (settings.haptics) {
      await HapticFeedback.heavyImpact();
    }
    if (settings.sound) {
      await SoundService.instance.play(
        id: timer.soundId ?? settings.alertSoundId,
        enabled: true,
      );
    }
  }

  static Future<NotificationDetails> _alertDetails({
    required String baseChannel,
    required String name,
    required String description,
    required Importance importance,
    Priority priority = Priority.high,
    AudioAttributesUsage usage = AudioAttributesUsage.notification,
    List<AndroidNotificationAction>? actions,
    String? soundId,
    bool fullScreenIntent = false,
    AndroidNotificationCategory? category,
  }) async {
    final settings = await getSettings();
    final resolved = (soundId == null || soundId.isEmpty)
        ? settings.alertSoundId
        : soundId;
    final suffix = SoundService.instance.channelSuffix(resolved);
    final sound = settings.sound
        ? await SoundService.instance.notificationSound(resolved)
        : null;
    final channelId = '${baseChannel}_$suffix';
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        name,
        description: description,
        importance: importance,
        playSound: settings.sound,
        sound: sound,
        audioAttributesUsage: usage,
      ),
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        name,
        channelDescription: description,
        importance: importance,
        priority: priority,
        playSound: settings.sound,
        sound: sound,
        audioAttributesUsage: usage,
        category: category,
        fullScreenIntent: fullScreenIntent,
        visibility: NotificationVisibility.public,
        actions: actions,
      ),
    );
  }

  static Future<void> rescheduleAll() async {
    final timers = await getTimers();
    final alarms = await getAlarms();
    await rescheduleTimers(timers);
    await rescheduleAlarms(alarms);
    await _syncNativeAlerts(timers: timers, alarms: alarms);
    await _syncHomeWidget(timers: timers, alarms: alarms);
  }

  static Future<void> rescheduleTimers(List<ClockTimer> timers) async {
    try {
      for (final timer in timers) {
        final doneId = _timerIdBase + (timer.id.hashCode.abs() % 4000);
        final delayId = _delayIdBase + (timer.id.hashCode.abs() % 4000);
        await _notifications.cancel(id: doneId);
        await _notifications.cancel(id: delayId);
        final delayDetails = await _alertDetails(
          baseChannel: _channelDelay,
          name: 'Delayed start',
          description: 'Timer delay finished',
          importance: Importance.max,
          priority: Priority.max,
          usage: AudioAttributesUsage.alarm,
          soundId: timer.soundId,
        );
        final doneDetails = await _alertDetails(
          baseChannel: _channelTimers,
          name: 'Timers',
          description: 'Countdown finished',
          importance: Importance.max,
          priority: Priority.max,
          usage: AudioAttributesUsage.alarm,
          soundId: timer.soundId,
        );
        final until = timer.delayUntil;
        if (until != null &&
            timer.alertOnDelayEnd &&
            until.isAfter(DateTime.now())) {
          await _notifications.zonedSchedule(
            id: delayId,
            title: timer.name,
            body: 'Timer started',
            scheduledDate: tz.TZDateTime.from(until.toUtc(), tz.local),
            notificationDetails: delayDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
        }
        if (!timer.isCountdown || !timer.isRunning) continue;
        final left = timer.remainingMs();
        if (left <= 0) continue;
        final when = tz.TZDateTime.now(tz.local).add(Duration(milliseconds: left));
        await _notifications.zonedSchedule(
          id: doneId,
          title: timer.name,
          body: 'Countdown finished',
          scheduledDate: when,
          notificationDetails: doneDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Timer schedule skipped: $e');
    }
    await _publishTimerStatus(timers);
    await _syncNativeAlerts(timers: timers, alarms: await getAlarms());
  }

  static Future<void> rescheduleAlarms(List<ClockAlarm> alarms) async {
    final settings = await getSettings();
    final loc = locationFor(settings);
    for (final alarm in alarms) {
      try {
        final base = _alarmIdBase + (alarm.id.hashCode.abs() % 4000);
        for (var i = 0; i < 8; i++) {
          await _notifications.cancel(id: base + i);
        }
        if (!alarm.enabled) {
          await _notifications.cancel(id: _snoozeNotifId(alarm.id));
          continue;
        }
        final details = await _alertDetails(
          baseChannel: _channelAlarms,
          name: 'Alarms',
          description: 'Orlux alarm times',
          importance: Importance.max,
          priority: Priority.max,
          usage: AudioAttributesUsage.alarm,
          soundId: alarm.soundId,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          actions: _alarmActions(alarm.snoozeMinutes),
        );
        final nowWall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
        final count = alarm.repeats ? 8 : 1;
        var cursor = nowWall;
        for (var n = 0; n < count; n++) {
          final next = ClockMath.nextAlarmAt(alarm, now: cursor);
          final when = tz.TZDateTime(
            alarm.useUtc ? tz.UTC : loc,
            next.year,
            next.month,
            next.day,
            next.hour,
            next.minute,
          );
          final nowTz = tz.TZDateTime.now(when.location);
          if (!when.isAfter(nowTz)) {
            cursor = next;
            continue;
          }
          final timeLabel = ClockMath.formatHourMinute(
            alarm.hour,
            alarm.minute,
            use24Hour: settings.use24Hour,
          );
          await _zonedAlarm(
            id: base + n,
            title: alarm.label,
            body: alarm.useUtc ? 'UTC $timeLabel' : timeLabel,
            when: when,
            details: details,
            payload: _alarmPayloadJson(alarm),
          );
          cursor = next;
        }
      } catch (e) {
        debugPrint('Alarm schedule skipped for ${alarm.id}: $e');
      }
    }
    await _publishNextAlarmStatus(alarms, settings);
    await _syncNativeAlerts(timers: await getTimers(), alarms: alarms);
  }

  static Future<NotificationDetails> _statusDetails({
    int? whenMs,
    bool chronometer = false,
    bool countDown = false,
    AndroidNotificationCategory category = AndroidNotificationCategory.status,
    List<AndroidNotificationAction>? actions,
  }) async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelStatus,
        'On now',
        description: 'Running timers and upcoming alarms',
        importance: Importance.low,
        playSound: false,
        showBadge: false,
      ),
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelStatus,
        'On now',
        channelDescription: 'Running timers and upcoming alarms',
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        silent: true,
        onlyAlertOnce: true,
        channelShowBadge: false,
        showWhen: chronometer || whenMs != null,
        when: whenMs,
        usesChronometer: chronometer,
        chronometerCountDown: countDown,
        category: category,
        visibility: NotificationVisibility.public,
        actions: actions,
      ),
    );
  }

  static Future<void> _publishTimerStatus(List<ClockTimer> timers) async {
    final settings = await getSettings();
    if (!settings.showStatusNotifications) {
      for (final id in _shownTimerStatusIds) {
        await _notifications.cancel(id: id);
      }
      _shownTimerStatusIds.clear();
      return;
    }
    final nextIds = <int>{};
    final now = DateTime.now();
    try {
      for (final timer in timers) {
        final delaying = timer.isDelaying(now);
        if (!timer.isRunning && !delaying) continue;
        final id = _timerStatusId(timer.id);
        nextIds.add(id);
        if (delaying) {
          final until = timer.delayUntil ?? now;
          await _notifications.show(
            id: id,
            title: timer.name,
            body: 'Starts in ${ClockMath.formatHms(until.difference(now))}',
            notificationDetails: await _statusDetails(
              whenMs: until.millisecondsSinceEpoch,
              chronometer: true,
              countDown: true,
              category: AndroidNotificationCategory.progress,
            ),
          );
          continue;
        }
        if (timer.isCountdown) {
          final left = timer.remainingMs(now);
          await _notifications.show(
            id: id,
            title: timer.name,
            body: 'Countdown',
            notificationDetails: await _statusDetails(
              whenMs: now.millisecondsSinceEpoch + left,
              chronometer: true,
              countDown: true,
              category: AndroidNotificationCategory.progress,
            ),
          );
        } else {
          await _notifications.show(
            id: id,
            title: timer.name,
            body: 'Stopwatch',
            notificationDetails: await _statusDetails(
              whenMs: now.millisecondsSinceEpoch - timer.elapsedMs(now),
              chronometer: true,
              category: AndroidNotificationCategory.stopwatch,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Timer status skipped: $e');
    }
    try {
      final active = await _notifications.getActiveNotifications();
      for (final n in active) {
        final id = n.id;
        if (id == null || id == _nextAlarmStatusId) continue;
        if (n.channelId == _channelStatus && !nextIds.contains(id)) {
          await _notifications.cancel(id: id);
        }
      }
    } catch (_) {}
    for (final id in _shownTimerStatusIds.difference(nextIds)) {
      await _notifications.cancel(id: id);
    }
    _shownTimerStatusIds
      ..clear()
      ..addAll(nextIds);
  }

  static Future<void> _publishNextAlarmStatus(
    List<ClockAlarm> alarms,
    ClockSettings settings,
  ) async {
    ClockAlarm? nextAlarm;
    DateTime? nextAt;
    try {
      if (!settings.showStatusNotifications) {
        await _notifications.cancel(id: _nextAlarmStatusId);
        return;
      }
      for (final alarm in alarms) {
        if (!alarm.enabled) continue;
        final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
        final at = ClockMath.nextAlarmAt(alarm, now: wall);
        if (nextAt == null || at.isBefore(nextAt)) {
          nextAt = at;
          nextAlarm = alarm;
        }
      }
      if (nextAlarm == null || nextAt == null) {
        await _notifications.cancel(id: _nextAlarmStatusId);
        return;
      }
      final timeLabel = ClockMath.formatHourMinute(
        nextAlarm.hour,
        nextAlarm.minute,
        use24Hour: settings.use24Hour,
      );
      final zone = nextAlarm.useUtc ? 'UTC' : settings.timezone;
      final wall = nextAlarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
      final skippable =
          ClockMath.dateKey(nextAt) == ClockMath.dateKey(wall);
      await _notifications.show(
        id: _nextAlarmStatusId,
        title: 'Alarm · $timeLabel',
        body: skippable
            ? '${nextAlarm.label} · $zone · Skip today if you are up'
            : '${nextAlarm.label} · $zone',
        payload: _alarmPayloadJson(nextAlarm),
        notificationDetails: await _statusDetails(
          whenMs: nextAt.millisecondsSinceEpoch,
          category: AndroidNotificationCategory.alarm,
          actions: [
            if (skippable)
              const AndroidNotificationAction(
                actionSkipToday,
                'Skip today',
                cancelNotification: true,
                showsUserInterface: true,
              ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Alarm status skipped: $e');
    }
  }

  static Future<void> _syncHomeWidget({
    List<ClockTimer>? timers,
    List<ClockAlarm>? alarms,
    ClockSettings? settings,
  }) async {
    settings ??= await getSettings();
    timers ??= await getTimers();
    alarms ??= await getAlarms();
    final now = DateTime.now();
    ClockTimer? live;
    var liveLeft = 1 << 30;
    for (final timer in timers) {
      final delaying = timer.isDelaying(now);
      if (!timer.isRunning && !delaying) continue;
      final left = delaying
          ? timer.delayRemainingSeconds(now) * 1000
          : timer.isCountdown
              ? timer.remainingMs(now)
              : 1 << 29;
      if (live == null || left < liveLeft) {
        live = timer;
        liveLeft = left;
      }
    }
    String timerMode = 'none';
    var timerAnchorMs = 0;
    if (live != null) {
      if (live.isDelaying(now) || live.isCountdown) {
        timerMode = 'down';
        timerAnchorMs = now.millisecondsSinceEpoch + liveLeft;
      } else {
        timerMode = 'up';
        timerAnchorMs = now.millisecondsSinceEpoch - live.elapsedMs(now);
      }
    }

    ClockAlarm? nextAlarm;
    DateTime? nextAt;
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
      final at = ClockMath.nextAlarmAt(alarm, now: wall);
      if (nextAt == null || at.isBefore(nextAt)) {
        nextAt = at;
        nextAlarm = alarm;
      }
    }
    String? alarmLine;
    if (nextAlarm != null) {
      final timeLabel = ClockMath.formatHourMinute(
        nextAlarm.hour,
        nextAlarm.minute,
        use24Hour: settings.use24Hour,
      );
      alarmLine = nextAlarm.useUtc
          ? 'Alarm UTC $timeLabel'
          : 'Alarm $timeLabel';
    }

    await WatchWidgetSync.sync(
      settings: settings,
      timerName: live?.name,
      timerMode: timerMode,
      timerAnchorMs: timerAnchorMs,
      alarmLine: alarmLine,
    );
  }

  static Future<void> _zonedAlarm({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required String payload,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) {
      return _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: payload,
      );
    }

    try {
      await schedule(AndroidScheduleMode.alarmClock);
    } catch (_) {
      try {
        await schedule(AndroidScheduleMode.exactAllowWhileIdle);
      } catch (e) {
        debugPrint('Exact alarm unavailable, using inexact: $e');
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    }
  }

  static Future<String> alarmSetMessage(ClockAlarm alarm) async {
    final settings = await getSettings();
    final nowWall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
    final next = ClockMath.nextAlarmAt(alarm, now: nowWall);
    return ClockMath.formatAlarmSetIn(next.difference(nowWall));
  }

  static bool canSkipToday(ClockAlarm alarm, ClockSettings settings) {
    if (!alarm.enabled) return false;
    final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
    final next = ClockMath.nextAlarmAt(alarm, now: wall);
    return ClockMath.dateKey(next) == ClockMath.dateKey(wall);
  }

  static Future<void> skipToday(ClockAlarm alarm) async {
    final settings = await getSettings();
    final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
    await _silenceUntilNext(alarm);
    await _logSleep(alarm, skipped: true, wake: wall);
  }

  /// Turns off the next ring without logging sleep.
  static Future<void> _silenceUntilNext(ClockAlarm alarm) async {
    final settings = await getSettings();
    final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
    if (!alarm.repeats) {
      await upsertAlarm(alarm.copyWith(enabled: false));
    } else {
      final next = ClockMath.nextAlarmAt(alarm, now: wall);
      await upsertAlarm(alarm.copyWith(skipDate: ClockMath.dateKey(next)));
    }
    await _notifications.cancel(id: _snoozeNotifId(alarm.id));
    await NativeAlerts.cancelIds([_snoozeNotifId(alarm.id)]);
  }

  /// Logs the night and turns off an alarm that has not rung yet.
  /// Waking before that alarm marks the night skipped.
  static Future<WakeUpResult> wakeUp() async {
    final settings = await getSettings();
    final alarms = await getAlarms();
    final ringing = AlarmRing.instance.ringing.value;
    final nowLocal = wallNow(settings);
    final nowUtc = DateTime.now().toUtc();
    final silence = ClockMath.alarmsSilencedByWake(
      alarms,
      nowFor: (alarm) => alarm.useUtc ? nowUtc : nowLocal,
      exceptId: ringing?.id,
    );
    for (final alarm in silence) {
      await _silenceUntilNext(alarm);
    }
    for (final alarm in alarms) {
      await _notifications.cancel(id: _snoozeNotifId(alarm.id));
    }
    await NativeAlerts.cancelIds([
      for (final alarm in alarms) _snoozeNotifId(alarm.id),
    ]);
    if (ringing != null) {
      await stopRingingAlarm();
    }
    final pending = await pendingBedtimeMs();
    if (pending != null && pending > 0) {
      final night = await endSleepSession(
        skipped: ringing == null && silence.isNotEmpty,
      );
      return WakeUpResult(
        night: night,
        silencedAlarm: silence.isNotEmpty,
        stoppedRinging: ringing != null,
      );
    }
    final key = ClockMath.dateKey(
      ringing?.useUtc == true ? nowUtc : nowLocal,
    );
    final nights = await getSleepNights();
    SleepNight? logged;
    for (final item in nights) {
      if (item.dateKey == key) logged = item;
    }
    return WakeUpResult(
      night: logged,
      silencedAlarm: silence.isNotEmpty,
      stoppedRinging: ringing != null,
    );
  }

  static Future<void> markBedtime() async {
    await _store.setInt(keyBedtimeMs, DateTime.now().millisecondsSinceEpoch);
    sleepRevision.value++;
  }

  static Future<void> clearBedtime() async {
    await _store.setInt(keyBedtimeMs, 0);
    sleepRevision.value++;
  }

  static Future<int?> pendingBedtimeMs() => _store.getInt(keyBedtimeMs);

  static Future<SleepNight?> endSleepSession({
    ClockAlarm? alarm,
    DateTime? wake,
    bool skipped = false,
  }) async {
    ClockAlarm? resolved = alarm;
    if (resolved == null) {
      final tracked = (await getAlarms()).where((a) => a.trackSleep);
      if (tracked.isNotEmpty) resolved = tracked.first;
    }
    return _logSleep(resolved, skipped: skipped, wake: wake, requireBedtime: true);
  }

  static Future<SleepStats> getSleepStats() async {
    return SleepStats(nights: await getSleepNights());
  }

  static Future<List<SleepNight>> getSleepNights() async {
    final raw = await _store.getString(keySleepNights);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map)
            SleepNight.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> upsertSleepNight(SleepNight night) async {
    final nights = await getSleepNights();
    nights.removeWhere((item) => item.dateKey == night.dateKey);
    nights.add(night);
    await _writeSleepNights(nights);
  }

  static Future<void> deleteSleepNight(String dateKey) async {
    final nights = await getSleepNights();
    nights.removeWhere((item) => item.dateKey == dateKey);
    await _writeSleepNights(nights);
  }

  static Future<void> _writeSleepNights(List<SleepNight> nights) async {
    nights.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    final trimmed =
        nights.length > 60 ? nights.sublist(nights.length - 60) : nights;
    await _store.setString(
      keySleepNights,
      jsonEncode(trimmed.map((night) => night.toJson()).toList()),
    );
    sleepRevision.value++;
  }

  static Future<SleepNight?> _logSleep(
    ClockAlarm? alarm, {
    required bool skipped,
    DateTime? wake,
    bool requireBedtime = false,
  }) async {
    if (alarm != null && !alarm.trackSleep && !requireBedtime) return null;
    final now = wake ?? DateTime.now();
    final stored = await _store.getInt(keyBedtimeMs);
    DateTime bedtime;
    if (stored != null && stored > 0) {
      bedtime = DateTime.fromMillisecondsSinceEpoch(stored);
    } else if (requireBedtime) {
      return null;
    } else if (alarm != null) {
      bedtime = DateTime(
        now.year,
        now.month,
        now.day,
        alarm.bedtimeHour,
        alarm.bedtimeMinute,
      );
      if (!bedtime.isBefore(now)) {
        bedtime = bedtime.subtract(const Duration(days: 1));
      }
    } else {
      return null;
    }
    var end = now;
    var minutes = end.difference(bedtime).inMinutes;
    if (minutes < 1) return null;
    if (minutes > 24 * 60) {
      minutes = 24 * 60;
      end = bedtime.add(Duration(minutes: minutes));
    }
    final nights = await getSleepNights();
    final key = ClockMath.dateKey(now);
    nights.removeWhere((n) => n.dateKey == key);
    final night = SleepNight(
      dateKey: key,
      minutes: minutes,
      bedtimeMs: bedtime.millisecondsSinceEpoch,
      wakeMs: end.millisecondsSinceEpoch,
      alarmId: alarm?.id,
      skipped: skipped,
      spans: [
        SleepSpan(
          startMs: bedtime.millisecondsSinceEpoch,
          endMs: end.millisecondsSinceEpoch,
        ),
      ],
    );
    nights.add(night);
    await _store.setInt(keyBedtimeMs, 0);
    await _writeSleepNights(nights);
    return night;
  }

  static Future<void> handleNativeFire(String? raw) async {
    final data = NativeAlerts.decodePayload(raw);
    if (data == null) return;
    if (data['k'] == 'dismiss') {
      await haltAlerts(clearOverlays: true);
      return;
    }
    if (data['k'] == 'alarm') {
      final ringing = _alarmFromPayload(data);
      if (ringing == null) return;
      final stored = (await getAlarms())
          .where((a) => a.id == ringing.id)
          .toList();
      final alarm = stored.isEmpty ? ringing : stored.first;
      AlarmRing.instance.show(alarm);
      await _onAlarmFired(alarm, fromNative: true);
      return;
    }
    if (data['k'] == 'timer') {
      final id = data['id'] as String? ?? '';
      final timers = await getTimers();
      final match = timers.where((t) => t.id == id);
      TimerRing.instance.show(
        match.isEmpty ? 'Timer' : match.first.name,
      );
      await settleCompleted();
    }
  }

  static Future<void> _syncNativeAlerts({
    required List<ClockTimer> timers,
    required List<ClockAlarm> alarms,
  }) async {
    final settings = await getSettings();
    final events = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (final timer in timers) {
      if (timer.isDelaying(now) && timer.alertOnDelayEnd) {
        final until = timer.delayUntil!;
        events.add({
          'id': _delayIdBase + (timer.id.hashCode.abs() % 4000),
          'atMs': until.millisecondsSinceEpoch,
          'title': timer.name,
          'body': 'Timer started',
          'loop': false,
          'soundPath': '',
          'payload': jsonEncode({'k': 'timer', 'id': timer.id}),
          'snooze': 0,
          'needsCode': false,
          'kind': 'timer',
          'crescendo': false,
        });
      }
      if (timer.isCountdown && timer.isRunning) {
        final left = timer.remainingMs(now);
        if (left > 0) {
          events.add({
            'id': _timerIdBase + (timer.id.hashCode.abs() % 4000),
            'atMs': now.millisecondsSinceEpoch + left,
            'title': timer.name,
            'body': 'Countdown finished',
            'loop': true,
            'soundPath': '',
            'payload': jsonEncode({'k': 'timer', 'id': timer.id}),
            'snooze': 0,
            'needsCode': false,
            'kind': 'timer',
            'crescendo': settings.crescendo,
          });
        }
      }
    }
    final loc = locationFor(settings);
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      final nowWall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
      final count = alarm.repeats ? 8 : 1;
      var cursor = nowWall;
      for (var n = 0; n < count; n++) {
        final next = ClockMath.nextAlarmAt(alarm, now: cursor);
        final when = tz.TZDateTime(
          alarm.useUtc ? tz.UTC : loc,
          next.year,
          next.month,
          next.day,
          next.hour,
          next.minute,
        );
        final nowTz = tz.TZDateTime.now(when.location);
        if (!when.isAfter(nowTz)) {
          cursor = next;
          continue;
        }
        final timeLabel = ClockMath.formatHourMinute(
          alarm.hour,
          alarm.minute,
          use24Hour: settings.use24Hour,
        );
        events.add({
          'id': _alarmIdBase + (alarm.id.hashCode.abs() % 4000) + n,
          'atMs': when.millisecondsSinceEpoch,
          'title': alarm.label,
          'body': alarm.useUtc ? 'UTC $timeLabel' : timeLabel,
          'loop': true,
          'soundPath': '',
          'payload': _alarmPayloadJson(alarm),
          'snooze': alarm.snoozeMinutes,
          'needsCode': alarm.wakeCode,
          'kind': 'alarm',
          'crescendo': settings.crescendo,
        });
        cursor = next;
      }
    }
    if (settings.bedtimeReminder) {
      for (final alarm in alarms) {
        if (!alarm.enabled || !alarm.trackSleep) continue;
        final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
        final at = ClockMath.nextAtHourMinute(
          alarm.bedtimeHour,
          alarm.bedtimeMinute,
          now: wall,
        );
        events.add({
          'id': _bedtimeIdBase + (alarm.id.hashCode.abs() % 4000),
          'atMs': at.millisecondsSinceEpoch,
          'title': 'Time for bed',
          'body': 'Mark Going to bed on Alarms to start tonight’s sleep log.',
          'loop': false,
          'soundPath': '',
          'payload': jsonEncode({'k': 'bedtime', 'id': alarm.id}),
          'snooze': 0,
          'needsCode': false,
          'kind': 'bedtime',
          'crescendo': false,
        });
      }
    }
    await NativeAlerts.replaceAll(events);
  }

  static Future<void> haltAlerts({bool clearOverlays = false}) async {
    _alarmRingStop?.cancel();
    await NativeAlerts.stop();
    await SoundService.instance.stop();
    if (clearOverlays) {
      AlarmRing.instance.clear();
      TimerRing.instance.clear();
    }
  }

  static Future<void> stopRingingAlarm() async {
    final ringing = AlarmRing.instance.ringing.value;
    await haltAlerts(clearOverlays: true);
    if (ringing != null) {
      await _notifications.cancel(id: _liveAlarmNotifId(ringing.id));
      await _logSleep(ringing, skipped: false);
    }
  }

  static Future<void> stopRingingTimer() async {
    await haltAlerts(clearOverlays: true);
    for (final timer in await getTimers()) {
      await _notifications.cancel(
        id: _timerLiveIdBase + (timer.id.hashCode.abs() % 4000),
      );
    }
  }

  static Future<void> snoozeRingingAlarm() async {
    final ringing = AlarmRing.instance.ringing.value;
    if (ringing == null || ringing.snoozeMinutes < 1) {
      await stopRingingAlarm();
      return;
    }
    _alarmRingStop?.cancel();
    await haltAlerts();
    AlarmRing.instance.clear();
    TimerRing.instance.clear();
    await _notifications.cancel(id: _liveAlarmNotifId(ringing.id));
    await NativeAlerts.snooze(
      id: _snoozeNotifId(ringing.id),
      minutes: ringing.snoozeMinutes,
      title: ringing.label,
      body: 'Snoozed',
      payload: _alarmPayloadJson(ringing),
      needsCode: ringing.wakeCode,
    );
    await scheduleSnooze(
      alarmId: ringing.id,
      minutes: ringing.snoozeMinutes,
      label: ringing.label,
      soundId: ringing.soundId,
      hour: ringing.hour,
      minute: ringing.minute,
      useUtc: ringing.useUtc,
    );
  }

  static Future<void> settleDueAlarms() async {
    if (_settlingAlarms) return;
    _settlingAlarms = true;
    try {
      final settings = await getSettings();
      final alarms = await getAlarms();
      for (final alarm in alarms) {
        if (!alarm.enabled) continue;
        final wall = alarm.useUtc ? DateTime.now().toUtc() : wallNow(settings);
        if (!_alarmMatchesMinute(alarm, wall)) continue;
        final stamp =
            '${wall.year}-${wall.month}-${wall.day} ${wall.hour}:${wall.minute}';
        if (_firedAlarmMinutes[alarm.id] == stamp) continue;
        _firedAlarmMinutes[alarm.id] = stamp;
        await _onAlarmFired(alarm);
      }
    } catch (e) {
      debugPrint('Due alarm check skipped: $e');
    } finally {
      _settlingAlarms = false;
    }
  }

  static bool _alarmMatchesMinute(ClockAlarm alarm, DateTime wall) {
    if (wall.hour != alarm.hour || wall.minute != alarm.minute) return false;
    if (alarm.days.isNotEmpty && !alarm.days.contains(wall.weekday)) {
      return false;
    }
    if (alarm.skipDate == ClockMath.dateKey(wall)) return false;
    if (alarm.skipFederalHolidays && FederalHolidays.isHoliday(wall)) {
      return false;
    }
    return true;
  }

  static Future<void> _onAlarmFired(
    ClockAlarm alarm, {
    bool fromNative = false,
  }) async {
    AlarmRing.instance.show(alarm);
    final now = DateTime.now();
    final stamp =
        '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    if (_firedAlarmMinutes[alarm.id] == stamp && fromNative) {
      return;
    }
    _firedAlarmMinutes[alarm.id] = stamp;
    final settings = await getSettings();
    if (!fromNative) {
      if (settings.haptics) {
        await HapticFeedback.heavyImpact();
      }
      if (settings.sound) {
        await SoundService.instance.play(
          id: alarm.soundId ?? settings.alertSoundId,
          enabled: true,
          loop: true,
          crescendo: settings.crescendo,
        );
        _alarmRingStop?.cancel();
        _alarmRingStop = Timer(const Duration(seconds: 45), () {
          SoundService.instance.stop();
        });
      }
    }
    if (!fromNative) {
    try {
      final details = await _alertDetails(
        baseChannel: _channelAlarms,
        name: 'Alarms',
        description: 'Orlux alarm times',
        importance: Importance.max,
        priority: Priority.max,
        usage: AudioAttributesUsage.alarm,
        soundId: alarm.soundId,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        actions: _alarmActions(alarm.snoozeMinutes),
      );
      final timeLabel = ClockMath.formatHourMinute(
        alarm.hour,
        alarm.minute,
        use24Hour: settings.use24Hour,
      );
      await _notifications.show(
        id: _liveAlarmNotifId(alarm.id),
        title: alarm.label,
        body: alarm.useUtc ? 'UTC $timeLabel' : timeLabel,
        notificationDetails: details,
        payload: _alarmPayloadJson(alarm),
      );
    } catch (e) {
      debugPrint('Alarm notify skipped: $e');
    }
    }
    if (!alarm.repeats) {
      await upsertAlarm(alarm.copyWith(enabled: false));
    } else {
      await rescheduleAlarms(await getAlarms());
    }
  }

  static Future<Map<String, dynamic>> buildExportMap() async {
    final snap = await _store.exportSnapshot();
    return {
      'schema_version': kExportSchemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'app': 'orlux',
      'export_note':
          'Plaintext backup. Prefer PIN-protected export if you store this file elsewhere.',
      ...snap,
    };
  }

  static Future<ExportResult> exportData({String? passphrase}) async {
    try {
      final data = await buildExportMap();
      String payload = const JsonEncoder.withIndent('  ').convert(data);
      if (passphrase != null && passphrase.isNotEmpty) {
        final envelope = ExportCrypto.encryptExport(
          plaintextJson: jsonEncode(data),
          passphrase: passphrase,
        );
        payload = const JsonEncoder.withIndent('  ').convert(envelope);
      }
      final saved = await FilePicker.saveFile(
        dialogTitle: passphrase != null && passphrase.isNotEmpty
            ? 'Save PIN-protected backup'
            : 'Save backup',
        fileName: passphrase != null && passphrase.isNotEmpty
            ? 'orlux_backup.enc.json'
            : 'orlux_backup.json',
        bytes: Uint8List.fromList(utf8.encode(payload)),
      );
      if (saved == null) return ExportResult.cancelled;
      return ExportResult.success;
    } catch (e) {
      debugPrint('Export error: $e');
      return ExportResult.failure;
    }
  }

  static Future<ImportResult> pickAndParseImport() async {
    try {
      final picked = await FilePicker.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null || picked.files.isEmpty) {
        return const ImportResult.failure('No file selected.');
      }
      final bytes = picked.files.first.bytes;
      if (bytes == null || bytes.isEmpty) {
        return const ImportResult.failure('The selected file is empty.');
      }
      return parseImportBytes(bytes);
    } catch (e) {
      debugPrint('Import parse error: $e');
      return const ImportResult.failure('Could not read the selected file.');
    }
  }

  static ImportResult parseImportBytes(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        return const ImportResult.failure('Invalid backup file: malformed JSON.');
      }
      return parseImportMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const ImportResult.failure('Invalid backup file: malformed JSON.');
    }
  }

  static ImportResult parseImportMap(Map<String, dynamic> decoded) {
    if (ExportCrypto.isEncryptedExport(decoded)) {
      return ImportResult.needsPassphrase(decoded);
    }
    return validateImportMap(decoded);
  }

  static ImportResult decryptAndValidateImport({
    required Map<String, dynamic> encryptedEnvelope,
    required String passphrase,
  }) {
    try {
      final plaintext = ExportCrypto.decryptExport(
        envelope: encryptedEnvelope,
        passphrase: passphrase,
      );
      final decoded = jsonDecode(plaintext);
      if (decoded is! Map) {
        return const ImportResult.failure('Invalid backup file: malformed JSON.');
      }
      return validateImportMap(Map<String, dynamic>.from(decoded));
    } on ExportCryptoException catch (e) {
      return ImportResult.failure(e.message);
    } catch (_) {
      return const ImportResult.failure('Could not unlock this backup.');
    }
  }

  static ImportResult validateImportMap(Map<String, dynamic> data) {
    if (data.containsKey('schema_version')) {
      final version = data['schema_version'];
      if (version is! num) {
        return const ImportResult.failure(
          'Invalid backup file: schema_version must be a number.',
        );
      }
      if (version > kExportSchemaVersion) {
        return const ImportResult.failure(
          'This backup is from a newer Orlux version.',
        );
      }
    }
    return ImportResult.success(data);
  }

  static Future<void> applyImport(Map<String, dynamic> validated) async {
    final copy = Map<String, dynamic>.from(validated);
    copy.remove('schema_version');
    copy.remove('exported_at');
    copy.remove('app');
    copy.remove('export_note');
    await _store.applyMap(copy);
    await rescheduleAll();
  }
}

@pragma('vm:entry-point')
void orluxNotificationTapBackground(NotificationResponse response) {
  unawaited(ClockStorage.handleNotificationResponse(response));
}
