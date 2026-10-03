class SleepNight {
  const SleepNight({
    required this.dateKey,
    required this.minutes,
    required this.bedtimeMs,
    required this.wakeMs,
    this.alarmId,
    this.skipped = false,
  });

  final String dateKey;
  final int minutes;
  final int bedtimeMs;
  final int wakeMs;
  final String? alarmId;
  final bool skipped;

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

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'minutes': minutes,
        'bedtimeMs': bedtimeMs,
        'wakeMs': wakeMs,
        'alarmId': alarmId,
        'skipped': skipped,
      };

  factory SleepNight.fromJson(Map<String, dynamic> json) {
    return SleepNight(
      dateKey: json['dateKey'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      bedtimeMs: (json['bedtimeMs'] as num?)?.toInt() ?? 0,
      wakeMs: (json['wakeMs'] as num?)?.toInt() ?? 0,
      alarmId: json['alarmId'] as String?,
      skipped: json['skipped'] as bool? ?? false,
    );
  }
}

class SleepStats {
  const SleepStats({
    required this.nights,
  });

  final List<SleepNight> nights;

  List<SleepNight> get last14 {
    final copy = [...nights]..sort((a, b) => a.dateKey.compareTo(b.dateKey));
    if (copy.length <= 14) return copy;
    return copy.sublist(copy.length - 14);
  }

  double? get averageHours {
    final recent = last14.where((n) => n.minutes > 0).toList();
    if (recent.isEmpty) return null;
    final total = recent.fold<int>(0, (sum, n) => sum + n.minutes);
    return total / recent.length / 60.0;
  }

  SleepNight? get latest => last14.isEmpty ? null : last14.last;
}
