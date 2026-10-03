import 'package:flutter_test/flutter_test.dart';
import 'package:orlux/models/clock_alarm.dart';
import 'package:orlux/models/clock_math.dart';
import 'package:orlux/models/clock_settings.dart';
import 'package:orlux/models/clock_timer.dart';
import 'package:orlux/models/federal_holidays.dart';
import 'package:orlux/models/sleep_night.dart';
import 'package:orlux/services/auto_lock_policy.dart';
import 'package:orlux/services/export_crypto.dart';

void main() {
  test('timer and alarm keep a per-item sound id', () {
    final timer = ClockTimer(
      id: 't',
      name: 'A',
      kind: TimerKind.stopwatch,
      soundId: 'bell',
    );
    expect(ClockTimer.fromJson(timer.toJson()).soundId, 'bell');
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 7,
      minute: 0,
      soundId: 'pulse',
    );
    expect(ClockAlarm.fromJson(alarm.toJson()).soundId, 'pulse');
    expect(ClockAlarm.fromJson(alarm.toJson()).skipFederalHolidays, isFalse);
    expect(
      ClockAlarm.fromJson(
        alarm.copyWith(skipFederalHolidays: true).toJson(),
      ).skipFederalHolidays,
      isTrue,
    );
  });

  test('formatElapsed pads minutes and centiseconds', () {
    expect(ClockMath.formatElapsed(65020), '01:05.02');
  });

  test('formatClock 12-hour uses AM and PM', () {
    expect(
      ClockMath.formatClock(DateTime(2026, 1, 1, 0, 5, 9), use24Hour: false),
      '12:05:09 AM',
    );
    expect(
      ClockMath.formatHm(DateTime(2026, 1, 1, 15, 4), use24Hour: false),
      '3:04 PM',
    );
    expect(
      ClockMath.formatHourMinute(7, 0, use24Hour: true),
      '07:00',
    );
  });

  test('night dim auto follows 9pm to 7am', () {
    const auto = ClockSettings(
      timezone: 'UTC',
      displayMode: DisplayMode.hybrid,
      haptics: true,
      sound: true,
      keepAwake: true,
      autoLockTimeoutSeconds: 0,
      alertSoundId: 'chime',
      use24Hour: true,
      showUtc: true,
      nightDimMode: NightDimMode.auto,
    );
    expect(auto.nightDimActive(DateTime(2026, 9, 22, 21, 0)), isTrue);
    expect(auto.nightDimActive(DateTime(2026, 9, 22, 6, 59)), isTrue);
    expect(auto.nightDimActive(DateTime(2026, 9, 22, 7, 0)), isFalse);
    expect(auto.nightDimActive(DateTime(2026, 9, 22, 12)), isFalse);
    const always = ClockSettings(
      timezone: 'UTC',
      displayMode: DisplayMode.hybrid,
      haptics: true,
      sound: true,
      keepAwake: true,
      autoLockTimeoutSeconds: 0,
      alertSoundId: 'chime',
      use24Hour: true,
      showUtc: true,
      nightDimMode: NightDimMode.always,
    );
    expect(always.nightDimActive(DateTime(2026, 9, 22, 12)), isTrue);
  });

  test('skip date moves a repeating alarm to the following day', () {
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 7,
      minute: 0,
      days: [DateTime.tuesday],
      skipDate: '2026-09-22',
    );
    final next = ClockMath.nextAlarmAt(
      alarm,
      now: DateTime(2026, 9, 21, 20),
    );
    expect(next, DateTime(2026, 9, 29, 7));
  });

  test('sleep stats average last nights', () {
    final stats = SleepStats(
      nights: [
        SleepNight(
          dateKey: '2026-09-20',
          minutes: 480,
          bedtimeMs: 1,
          wakeMs: 2,
        ),
        SleepNight(
          dateKey: '2026-09-21',
          minutes: 360,
          bedtimeMs: 1,
          wakeMs: 2,
        ),
      ],
    );
    expect(stats.averageHours, closeTo(7.0, 0.01));
    expect(stats.latest!.hours, 6);
    expect(stats.latest!.shortLabel, 'Sep 21');
  });

  test('formatHms uses hours minutes and seconds', () {
    expect(ClockMath.formatHms(const Duration(hours: 1, minutes: 2, seconds: 3)), '1h 02m 03s');
    expect(ClockMath.formatHms(const Duration(seconds: 9)), '9s');
  });

  test('stopwatch elapsed includes runningSince', () {
    final start = DateTime(2026, 9, 15, 12, 0, 0);
    final timer = ClockTimer(
      id: 't',
      name: 'A',
      kind: TimerKind.stopwatch,
      accumulatedMs: 1000,
      runningSince: start,
    );
    expect(
      timer.elapsedMs(start.add(const Duration(seconds: 2))),
      3000,
    );
  });

  test('delayed start promotes once delayUntil passes', () {
    final until = DateTime(2026, 9, 15, 12, 0, 5);
    final timer = ClockTimer(
      id: 'd',
      name: 'D',
      kind: TimerKind.stopwatch,
      delaySeconds: 5,
      delayUntil: until,
      alertOnDelayEnd: true,
    );
    expect(timer.isDelaying(DateTime(2026, 9, 15, 12, 0, 2)), isTrue);
    expect(timer.promoteDelay(DateTime(2026, 9, 15, 12, 0, 2)), isNull);
    final started = timer.promoteDelay(DateTime(2026, 9, 15, 12, 0, 6));
    expect(started, isNotNull);
    expect(started!.isRunning, isTrue);
    expect(started.delayUntil, isNull);
  });

  test('timer and alarm keep a per-item sound id', () {
    final timer = ClockTimer(
      id: 't',
      name: 'A',
      kind: TimerKind.countdown,
      durationMs: 1000,
      soundId: 'bell',
    );
    expect(ClockTimer.fromJson(timer.toJson()).soundId, 'bell');
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 7,
      minute: 0,
      soundId: 'pulse',
    );
    expect(ClockAlarm.fromJson(alarm.toJson()).soundId, 'pulse');
    expect(timer.copyWith(clearSound: true).soundId, isNull);
  });

  test('idle countdown shows the set duration, not zero', () {
    final timer = ClockTimer(
      id: 'c',
      name: 'Tea',
      kind: TimerKind.countdown,
      durationMs: 5 * 60 * 1000,
    );
    expect(timer.displayMs(), 5 * 60 * 1000);
    expect(timer.progress(), 0);
    expect(ClockMath.formatElapsed(timer.displayMs()), '05:00.00');
  });

  test('finished countdown still displays the set duration', () {
    final timer = ClockTimer(
      id: 'c',
      name: 'Tea',
      kind: TimerKind.countdown,
      durationMs: 60000,
      accumulatedMs: 60000,
    );
    expect(timer.isFinished, isTrue);
    expect(timer.remainingMs(), 0);
    expect(timer.displayMs(), 60000);
    expect(timer.progress(), 1);
  });

  test('running countdown displays remaining and fills the ring', () {
    final start = DateTime(2026, 9, 15, 12, 0, 0);
    final timer = ClockTimer(
      id: 'c',
      name: 'Tea',
      kind: TimerKind.countdown,
      durationMs: 10000,
      runningSince: start,
    );
    final now = start.add(const Duration(seconds: 4));
    expect(timer.displayMs(now), 6000);
    expect(timer.progress(now), closeTo(0.4, 0.001));
  });

  test('next one-shot alarm rolls to tomorrow if time passed', () {
    final alarm = ClockAlarm(id: 'a', label: 'x', hour: 7, minute: 0);
    final now = DateTime(2026, 9, 15, 8, 0);
    final next = ClockMath.nextAlarmAt(alarm, now: now);
    expect(next, DateTime(2026, 9, 16, 7, 0));
  });

  test('repeating alarm picks the next matching weekday', () {
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 6,
      minute: 30,
      days: [DateTime.wednesday],
    );
    final tuesday = DateTime(2026, 9, 15, 12); // Tuesday
    final next = ClockMath.nextAlarmAt(alarm, now: tuesday);
    expect(next.weekday, DateTime.wednesday);
    expect(next.hour, 6);
    expect(next.minute, 30);
  });

  test('US federal holidays include observed Independence Day 2026', () {
    expect(FederalHolidays.isHoliday(DateTime(2026, 7, 3)), isTrue);
    expect(FederalHolidays.isHoliday(DateTime(2026, 7, 4)), isFalse);
    expect(FederalHolidays.isHoliday(DateTime(2026, 11, 26)), isTrue);
    expect(FederalHolidays.isHoliday(DateTime(2026, 1, 19)), isTrue);
  });

  test('nextAtHourMinute rolls to tomorrow after the hour has passed', () {
    expect(
      ClockMath.nextAtHourMinute(
        22,
        30,
        now: DateTime(2026, 9, 22, 21, 0),
      ),
      DateTime(2026, 9, 22, 22, 30),
    );
    expect(
      ClockMath.nextAtHourMinute(
        22,
        30,
        now: DateTime(2026, 9, 22, 22, 30),
      ),
      DateTime(2026, 9, 23, 22, 30),
    );
  });

  test('sleep night meetsGoal allows a small slack', () {
    const night = SleepNight(
      dateKey: '2026-09-22',
      minutes: 446,
      bedtimeMs: 0,
      wakeMs: 1,
    );
    expect(night.meetsGoal(7.5), isTrue);
    expect(night.meetsGoal(8), isFalse);
  });

  test('holiday skip moves a morning alarm to the next business day', () {
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 7,
      minute: 0,
      skipFederalHolidays: true,
    );
    final next = ClockMath.nextAlarmAt(
      alarm,
      now: DateTime(2026, 7, 3, 6),
    );
    expect(next, DateTime(2026, 7, 6, 7));
  });

  test('holiday skip for a Monday-only alarm fires Tuesday', () {
    final alarm = ClockAlarm(
      id: 'a',
      label: 'x',
      hour: 7,
      minute: 0,
      days: [DateTime.monday],
      skipFederalHolidays: true,
    );
    final next = ClockMath.nextAlarmAt(
      alarm,
      now: DateTime(2026, 1, 18, 12),
    );
    expect(next, DateTime(2026, 1, 20, 7));
  });

  test('alarm set confirmation matches Google Clock phrasing', () {
    expect(
      ClockMath.formatAlarmSetIn(const Duration(seconds: 20)),
      'Alarm set for less than 1 minute from now',
    );
    expect(
      ClockMath.formatAlarmSetIn(const Duration(minutes: 5)),
      'Alarm set for 5 minutes from now',
    );
    expect(
      ClockMath.formatAlarmSetIn(const Duration(hours: 1)),
      'Alarm set for 1 hour from now',
    );
    expect(
      ClockMath.formatAlarmSetIn(const Duration(hours: 2, minutes: 15)),
      'Alarm set for 2 hours and 15 minutes from now',
    );
    expect(
      ClockMath.formatAlarmSetIn(const Duration(days: 1, hours: 2, minutes: 3)),
      'Alarm set for 1 day, 2 hours and 3 minutes from now',
    );
  });

  test('UTC-off faces drop analog-plus-UTC dual and stacked', () {
    expect(DisplayMode.analog.withoutUtc, DisplayMode.analogLocal);
    expect(DisplayMode.dual.withoutUtc, DisplayMode.analogLocal);
    expect(DisplayMode.stacked.withoutUtc, DisplayMode.digital);
    expect(DisplayMode.hybrid.withoutUtc, DisplayMode.hybrid);
    expect(
      DisplayModeLabel.availableFaces(showUtc: false),
      [DisplayMode.hybrid, DisplayMode.analogLocal, DisplayMode.digital],
    );
  });


  test('auto-lock immediate on pause', () {
    expect(AutoLockPolicy.lockImmediatelyOnPause(0), isTrue);
    expect(AutoLockPolicy.lockImmediatelyOnPause(30), isFalse);
  });

  test('export crypto round-trip', () {
    const json = '{"hello":"orlux"}';
    final envelope = ExportCrypto.encryptExport(
      plaintextJson: json,
      passphrase: '1234',
    );
    expect(
      ExportCrypto.decryptExport(envelope: envelope, passphrase: '1234'),
      json,
    );
  });
}
