import 'clock_math.dart';

enum DisplayMode { hybrid, analog, analogLocal, dual, digital, stacked }

enum NightDimMode { off, auto, always }

extension DisplayModeLabel on DisplayMode {
  String get label => switch (this) {
        DisplayMode.hybrid => 'Hybrid',
        DisplayMode.analog => 'Analog + UTC',
        DisplayMode.analogLocal => 'Analog',
        DisplayMode.dual => 'Dual analog',
        DisplayMode.stacked => 'Stacked',
        DisplayMode.digital => 'Digital',
      };

  bool get needsUtc => switch (this) {
        DisplayMode.analog || DisplayMode.dual || DisplayMode.stacked => true,
        _ => false,
      };

  DisplayMode get withoutUtc => switch (this) {
        DisplayMode.analog || DisplayMode.dual => DisplayMode.analogLocal,
        DisplayMode.stacked => DisplayMode.digital,
        _ => this,
      };

  static List<DisplayMode> availableFaces({required bool showUtc}) {
    if (showUtc) return DisplayMode.values;
    return const [
      DisplayMode.hybrid,
      DisplayMode.analogLocal,
      DisplayMode.digital,
    ];
  }
}

extension NightDimModeLabel on NightDimMode {
  String get label => switch (this) {
        NightDimMode.off => 'Off',
        NightDimMode.auto => 'Auto 9pm–7am',
        NightDimMode.always => 'Always',
      };
}

class ClockSettings {
  const ClockSettings({
    required this.timezone,
    required this.displayMode,
    required this.haptics,
    required this.sound,
    required this.keepAwake,
    required this.autoLockTimeoutSeconds,
    required this.alertSoundId,
    required this.use24Hour,
    required this.showUtc,
    required this.nightDimMode,
    this.showStatusNotifications = true,
    this.crescendo = true,
    this.bedtimeReminder = true,
    this.sleepGoalMinutes = 450,
    this.widgetSeconds = true,
  });

  final String timezone;
  final DisplayMode displayMode;
  final bool haptics;
  final bool sound;
  final bool keepAwake;
  final int autoLockTimeoutSeconds;
  final String alertSoundId;
  final bool use24Hour;
  final bool showUtc;
  final NightDimMode nightDimMode;
  final bool showStatusNotifications;
  final bool crescendo;
  final bool bedtimeReminder;

  /// Target time in bed, default 7.5 hours.
  final int sleepGoalMinutes;
  final bool widgetSeconds;

  double get sleepGoalHours => sleepGoalMinutes / 60.0;

  DisplayMode get effectiveDisplayMode =>
      showUtc ? displayMode : displayMode.withoutUtc;

  bool nightDimActive(DateTime local) {
    return switch (nightDimMode) {
      NightDimMode.off => false,
      NightDimMode.always => true,
      NightDimMode.auto => ClockMath.isNightHour(local),
    };
  }

  ClockSettings copyWith({
    String? timezone,
    DisplayMode? displayMode,
    bool? haptics,
    bool? sound,
    bool? keepAwake,
    int? autoLockTimeoutSeconds,
    String? alertSoundId,
    bool? use24Hour,
    bool? showUtc,
    NightDimMode? nightDimMode,
    bool? showStatusNotifications,
    bool? crescendo,
    bool? bedtimeReminder,
    int? sleepGoalMinutes,
    bool? widgetSeconds,
  }) {
    return ClockSettings(
      timezone: timezone ?? this.timezone,
      displayMode: displayMode ?? this.displayMode,
      haptics: haptics ?? this.haptics,
      sound: sound ?? this.sound,
      keepAwake: keepAwake ?? this.keepAwake,
      autoLockTimeoutSeconds:
          autoLockTimeoutSeconds ?? this.autoLockTimeoutSeconds,
      alertSoundId: alertSoundId ?? this.alertSoundId,
      use24Hour: use24Hour ?? this.use24Hour,
      showUtc: showUtc ?? this.showUtc,
      nightDimMode: nightDimMode ?? this.nightDimMode,
      showStatusNotifications:
          showStatusNotifications ?? this.showStatusNotifications,
      crescendo: crescendo ?? this.crescendo,
      bedtimeReminder: bedtimeReminder ?? this.bedtimeReminder,
      sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
      widgetSeconds: widgetSeconds ?? this.widgetSeconds,
    );
  }
}
