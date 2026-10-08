import 'clock_alarm.dart';
import 'federal_holidays.dart';

class ClockMath {
  ClockMath._();

  static String two(int n) => n.toString().padLeft(2, '0');

  static String formatClock(
    DateTime dt, {
    bool use24Hour = true,
    bool seconds = true,
  }) {
    final minSec =
        '${two(dt.minute)}${seconds ? ':${two(dt.second)}' : ''}';
    if (use24Hour) {
      return '${two(dt.hour)}:$minSec';
    }
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minSec $period';
  }

  static String formatHm(DateTime dt, {bool use24Hour = true}) =>
      formatClock(dt, use24Hour: use24Hour, seconds: false);

  static String formatHourMinute(
    int hour,
    int minute, {
    bool use24Hour = true,
  }) {
    return formatHm(
      DateTime(2000, 1, 1, hour, minute),
      use24Hour: use24Hour,
    );
  }

  /// Dim window for Auto night face: 9pm through 6:59am.
  static bool isNightHour(DateTime dt) => dt.hour >= 21 || dt.hour < 7;

  static String dateKey(DateTime dt) =>
      '${dt.year}-${two(dt.month)}-${two(dt.day)}';

  static DateTime nextAtHourMinute(
    int hour,
    int minute, {
    required DateTime now,
  }) {
    var at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  static String formatHms(Duration d) {
    final total = d.isNegative ? Duration.zero : d;
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    final s = total.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${two(m)}m ${two(s)}s';
    if (m > 0) return '${m}m ${two(s)}s';
    return '${s}s';
  }

  static String formatElapsed(int milliseconds) {
    final total = milliseconds < 0 ? 0 : milliseconds;
    final hours = total ~/ 3600000;
    final minutes = (total % 3600000) ~/ 60000;
    final seconds = (total % 60000) ~/ 1000;
    final cs = (total % 1000) ~/ 10;
    if (hours > 0) {
      return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    }
    return '${two(minutes)}:${two(seconds)}.${two(cs)}';
  }

  static DateTime utcNow([DateTime? now]) => (now ?? DateTime.now()).toUtc();

  /// Next fire for [alarm] in the given zone (naive wall clock on [now]).
  static DateTime nextAlarmAt(
    ClockAlarm alarm, {
    required DateTime now,
  }) {
    final clock = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
    );
    if (alarm.skipFederalHolidays && FederalHolidays.isHoliday(clock)) {
      final todayAt = DateTime(
        clock.year,
        clock.month,
        clock.day,
        alarm.hour,
        alarm.minute,
      );
      final matchesToday =
          alarm.days.isEmpty || alarm.days.contains(clock.weekday);
      if (matchesToday && !todayAt.isAfter(clock)) {
        return FederalHolidays.nextBusinessDayAt(todayAt);
      }
    }

    var day = DateTime(clock.year, clock.month, clock.day);
    for (var i = 0; i < 400; i++) {
      final at = DateTime(day.year, day.month, day.day, alarm.hour, alarm.minute);
      final matches = alarm.days.isEmpty || alarm.days.contains(day.weekday);
      if (matches && at.isAfter(clock)) {
        var candidate = at;
        if (alarm.skipFederalHolidays && FederalHolidays.isHoliday(day)) {
          candidate = FederalHolidays.nextBusinessDayAt(at);
        }
        if (alarm.skipDate != null &&
            dateKey(candidate) == alarm.skipDate) {
          day = DateTime(candidate.year, candidate.month, candidate.day)
              .add(const Duration(days: 1));
          continue;
        }
        return candidate;
      }
      day = day.add(const Duration(days: 1));
    }
    return DateTime(
      clock.year,
      clock.month,
      clock.day,
      alarm.hour,
      alarm.minute,
    ).add(const Duration(days: 1));
  }

  /// Google Clock-style confirmation, e.g. "Alarm set for 2 hours and 15 minutes from now".
  static String formatAlarmSetIn(Duration until) {
    final safe = until.isNegative ? Duration.zero : until;
    if (safe.inSeconds < 60) {
      return 'Alarm set for less than 1 minute from now';
    }
    var minutes = safe.inMinutes;
    if (safe.inSeconds % 60 > 0) minutes += 1;
    final days = minutes ~/ (24 * 60);
    minutes %= 24 * 60;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add(days == 1 ? '1 day' : '$days days');
    if (hours > 0) parts.add(hours == 1 ? '1 hour' : '$hours hours');
    if (mins > 0) parts.add(mins == 1 ? '1 minute' : '$mins minutes');
    if (parts.isEmpty) {
      return 'Alarm set for less than 1 minute from now';
    }
    if (parts.length == 1) {
      return 'Alarm set for ${parts[0]} from now';
    }
    if (parts.length == 2) {
      return 'Alarm set for ${parts[0]} and ${parts[1]} from now';
    }
    return 'Alarm set for ${parts[0]}, ${parts[1]} and ${parts[2]} from now';
  }

  /// Every enabled alarm that would still ring today.
  /// I’m up turns each of these off for that day.
  static List<ClockAlarm> alarmsSilencedByWake(
    List<ClockAlarm> alarms, {
    required DateTime Function(ClockAlarm alarm) nowFor,
    String? exceptId,
  }) {
    final due = <ClockAlarm>[];
    for (final alarm in alarms) {
      if (!alarm.enabled || alarm.id == exceptId) continue;
      final now = nowFor(alarm);
      final next = nextAlarmAt(alarm, now: now);
      if (dateKey(next) == dateKey(now)) due.add(alarm);
    }
    due.sort((a, b) {
      final aNext = nextAlarmAt(a, now: nowFor(a));
      final bNext = nextAlarmAt(b, now: nowFor(b));
      return aNext.compareTo(bNext);
    });
    return due;
  }
}
