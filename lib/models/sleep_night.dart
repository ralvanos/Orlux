import 'clock_math.dart';

class SleepSpan {
  const SleepSpan({
    required this.startMs,
    required this.endMs,
  });

  final int startMs;
  final int endMs;

  int get minutes {
    final delta = endMs - startMs;
    if (delta <= 0) return 0;
    return delta ~/ 60000;
  }

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
      };

  factory SleepSpan.fromJson(Map<String, dynamic> json) {
    return SleepSpan(
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 0,
    );
  }

  /// Places a clock-time stretch on the morning dated [wakeDay].
  /// A start at noon or later is the evening before. If the end clock time
  /// is not later, it falls on the next calendar day.
  static SleepSpan? onWakeDay({
    required DateTime wakeDay,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) {
    if (startHour == endHour && startMinute == endMinute) return null;
    final day = DateTime(wakeDay.year, wakeDay.month, wakeDay.day);
    final prev = day.subtract(const Duration(days: 1));
    DateTime at(DateTime base, int hour, int minute) =>
        DateTime(base.year, base.month, base.day, hour, minute);
    final evening = startHour >= 12;
    final start = at(evening ? prev : day, startHour, startMinute);
    var end = at(evening ? prev : day, endHour, endMinute);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }
    if (!end.isAfter(start)) return null;
    return SleepSpan(
      startMs: start.millisecondsSinceEpoch,
      endMs: end.millisecondsSinceEpoch,
    );
  }

  static List<SleepSpan> merge(List<SleepSpan> spans) {
    final valid = spans.where((span) => span.endMs > span.startMs).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    if (valid.isEmpty) return const [];
    final merged = <SleepSpan>[valid.first];
    for (final span in valid.skip(1)) {
      final last = merged.last;
      if (span.startMs <= last.endMs) {
        final end = span.endMs > last.endMs ? span.endMs : last.endMs;
        merged[merged.length - 1] =
            SleepSpan(startMs: last.startMs, endMs: end);
      } else {
        merged.add(span);
      }
    }
    return merged;
  }
}

class SleepNight {
  const SleepNight({
    required this.dateKey,
    required this.minutes,
    required this.bedtimeMs,
    required this.wakeMs,
    this.alarmId,
    this.skipped = false,
    this.spans = const [],
  });

  final String dateKey;
  final int minutes;
  final int bedtimeMs;
  final int wakeMs;
  final String? alarmId;
  final bool skipped;

  /// Asleep intervals. Empty on older logs, which fall back to bedtime–wake.
  final List<SleepSpan> spans;

  String get shortLabel {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = int.tryParse(parts[1]) ?? 0;
    final day = int.tryParse(parts[2]) ?? 0;
    if (month < 1 || month > 12) return dateKey;
    return '${months[month - 1]} $day';
  }

  double get hours => minutes / 60.0;

  bool meetsGoal(double goalHours) => hours + 0.08 >= goalHours;

  List<SleepSpan> get resolvedSpans {
    if (spans.isNotEmpty) return SleepSpan.merge(spans);
    if (wakeMs > bedtimeMs) {
      return [SleepSpan(startMs: bedtimeMs, endMs: wakeMs)];
    }
    return const [];
  }

  String rangesLabel({bool use24Hour = true}) {
    final list = resolvedSpans;
    if (list.isEmpty) return '';
    return list.map((span) {
      final start = DateTime.fromMillisecondsSinceEpoch(span.startMs);
      final end = DateTime.fromMillisecondsSinceEpoch(span.endMs);
      return '${ClockMath.formatHm(start, use24Hour: use24Hour)}–${ClockMath.formatHm(end, use24Hour: use24Hour)}';
    }).join(' · ');
  }

  static DateTime? dateOf(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  factory SleepNight.fromSpans({
    required String dateKey,
    required List<SleepSpan> spans,
    String? alarmId,
    bool skipped = false,
  }) {
    final merged = SleepSpan.merge(spans);
    var minutes = 0;
    for (final span in merged) {
      minutes += span.minutes;
    }
    if (minutes > 24 * 60) minutes = 24 * 60;
    return SleepNight(
      dateKey: dateKey,
      minutes: minutes,
      bedtimeMs: merged.isEmpty ? 0 : merged.first.startMs,
      wakeMs: merged.isEmpty ? 0 : merged.last.endMs,
      spans: merged,
      alarmId: alarmId,
      skipped: skipped,
    );
  }

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'minutes': minutes,
        'bedtimeMs': bedtimeMs,
        'wakeMs': wakeMs,
        'alarmId': alarmId,
        'skipped': skipped,
        'spans': spans.map((span) => span.toJson()).toList(),
      };

  factory SleepNight.fromJson(Map<String, dynamic> json) {
    final rawSpans = json['spans'];
    return SleepNight(
      dateKey: json['dateKey'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      bedtimeMs: (json['bedtimeMs'] as num?)?.toInt() ?? 0,
      wakeMs: (json['wakeMs'] as num?)?.toInt() ?? 0,
      alarmId: json['alarmId'] as String?,
      skipped: json['skipped'] as bool? ?? false,
      spans: [
        if (rawSpans is List)
          for (final item in rawSpans)
            if (item is Map)
              SleepSpan.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

class WakeUpResult {
  const WakeUpResult({
    this.night,
    this.silencedAlarm = false,
    this.stoppedRinging = false,
  });

  final SleepNight? night;
  final bool silencedAlarm;
  final bool stoppedRinging;
}

class SleepStats {
  const SleepStats({
    required this.nights,
  });

  final List<SleepNight> nights;

  List<SleepNight> get chronological {
    final copy = [...nights]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return copy;
  }

  List<SleepNight> get last7 => _tail(7);

  List<SleepNight> get last14 => _tail(14);

  List<SleepNight> _tail(int count) {
    final copy = chronological;
    if (copy.length <= count) return copy;
    return copy.sublist(copy.length - count);
  }

  double? get averageHours {
    final recent = last14.where((n) => n.minutes > 0).toList();
    if (recent.isEmpty) return null;
    final total = recent.fold<int>(0, (sum, n) => sum + n.minutes);
    return total / recent.length / 60.0;
  }

  SleepNight? get latest => last14.isEmpty ? null : last14.last;
}
