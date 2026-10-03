class ClockAlarm {
  const ClockAlarm({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    this.enabled = true,
    this.days = const [],
    this.useUtc = false,
    this.snoozeMinutes = 5,
    this.soundId,
    this.skipFederalHolidays = false,
    this.skipDate,
    this.trackSleep = false,
    this.bedtimeHour = 23,
    this.bedtimeMinute = 0,
    this.wakeCode = false,
  });

  final String id;
  final String label;
  final int hour;
  final int minute;
  final bool enabled;

  /// Empty = next one-shot. Otherwise DateTime.monday..sunday.
  final List<int> days;
  final bool useUtc;
  final int snoozeMinutes;
  final String? soundId;

  /// When true, a fire that lands on a U.S. federal holiday moves to the
  /// next weekday that is not a holiday.
  final bool skipFederalHolidays;

  /// `yyyy-MM-dd` of the next occurrence to skip (already awake).
  final String? skipDate;

  final bool trackSleep;
  final int bedtimeHour;
  final int bedtimeMinute;

  /// Shuffled 4-digit wake code to stop the alarm.
  final bool wakeCode;

  bool get repeats => days.isNotEmpty;

  ClockAlarm copyWith({
    String? label,
    int? hour,
    int? minute,
    bool? enabled,
    List<int>? days,
    bool? useUtc,
    int? snoozeMinutes,
    String? soundId,
    bool? skipFederalHolidays,
    String? skipDate,
    bool clearSkipDate = false,
    bool? trackSleep,
    int? bedtimeHour,
    int? bedtimeMinute,
    bool? wakeCode,
    bool clearSound = false,
  }) {
    return ClockAlarm(
      id: id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      days: days ?? this.days,
      useUtc: useUtc ?? this.useUtc,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      soundId: clearSound ? null : (soundId ?? this.soundId),
      skipFederalHolidays:
          skipFederalHolidays ?? this.skipFederalHolidays,
      skipDate: clearSkipDate ? null : (skipDate ?? this.skipDate),
      trackSleep: trackSleep ?? this.trackSleep,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      wakeCode: wakeCode ?? this.wakeCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'days': days,
        'useUtc': useUtc,
        'snoozeMinutes': snoozeMinutes,
        'soundId': soundId,
        'skipFederalHolidays': skipFederalHolidays,
        'skipDate': skipDate,
        'trackSleep': trackSleep,
        'bedtimeHour': bedtimeHour,
        'bedtimeMinute': bedtimeMinute,
        'wakeCode': wakeCode,
      };

  factory ClockAlarm.fromJson(Map<String, dynamic> json) {
    return ClockAlarm(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? 'Alarm',
      hour: (json['hour'] as num?)?.toInt() ?? 7,
      minute: (json['minute'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      days: (json['days'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const [],
      useUtc: json['useUtc'] as bool? ?? false,
      snoozeMinutes: (json['snoozeMinutes'] as num?)?.toInt() ?? 5,
      soundId: json['soundId'] as String?,
      skipFederalHolidays: json['skipFederalHolidays'] as bool? ?? false,
      skipDate: json['skipDate'] as String?,
      trackSleep: json['trackSleep'] as bool? ?? false,
      bedtimeHour: (json['bedtimeHour'] as num?)?.toInt() ?? 23,
      bedtimeMinute: (json['bedtimeMinute'] as num?)?.toInt() ?? 0,
      wakeCode: json['wakeCode'] as bool? ?? false,
    );
  }
}
