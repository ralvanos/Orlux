enum TimerKind { stopwatch, countdown }

class ClockTimer {
  const ClockTimer({
    required this.id,
    required this.name,
    required this.kind,
    this.accumulatedMs = 0,
    this.runningSince,
    this.durationMs = 0,
    this.laps = const [],
    this.onCompleteStartId,
    this.delaySeconds = 0,
    this.delayUntil,
    this.alertOnDelayEnd = true,
    this.soundId,
  });

  final String id;
  final String name;
  final TimerKind kind;
  final int accumulatedMs;
  final DateTime? runningSince;
  final int durationMs;
  final List<int> laps;
  final String? onCompleteStartId;
  final int delaySeconds;
  final DateTime? delayUntil;
  final bool alertOnDelayEnd;
  final String? soundId;

  bool get isRunning => runningSince != null;
  bool get isCountdown => kind == TimerKind.countdown;

  bool isDelaying([DateTime? now]) {
    final until = delayUntil;
    if (until == null) return false;
    return (now ?? DateTime.now()).isBefore(until);
  }

  int delayRemainingSeconds([DateTime? now]) {
    final until = delayUntil;
    if (until == null) return 0;
    final left = until.difference(now ?? DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

  ClockTimer? promoteDelay(DateTime now) {
    final until = delayUntil;
    if (until == null || now.isBefore(until)) return null;
    return copyWith(runningSince: until, clearDelayUntil: true);
  }

  int elapsedMs([DateTime? now]) {
    var ms = accumulatedMs;
    final started = runningSince;
    if (started != null) {
      ms += (now ?? DateTime.now()).difference(started).inMilliseconds;
    }
    if (ms < 0) return 0;
    return ms;
  }

  int remainingMs([DateTime? now]) {
    if (!isCountdown) return 0;
    final left = durationMs - elapsedMs(now);
    return left < 0 ? 0 : left;
  }

  /// Digits on the card: the set duration when idle/finished, remaining while
  /// a countdown is in progress, elapsed for a stopwatch.
  int displayMs([DateTime? now]) {
    if (isDelaying(now)) {
      return delayRemainingSeconds(now) * 1000;
    }
    if (!isCountdown) return elapsedMs(now);
    if (!isRunning && (elapsedMs(now) == 0 || remainingMs(now) == 0)) {
      return durationMs < 0 ? 0 : durationMs;
    }
    return remainingMs(now);
  }

  /// 0..1 fill for the countdown ring (delay uses delaySeconds).
  double progress([DateTime? now]) {
    if (isDelaying(now)) {
      if (delaySeconds <= 0) return 0;
      final done = delaySeconds - delayRemainingSeconds(now);
      return (done / delaySeconds).clamp(0.0, 1.0);
    }
    if (!isCountdown || durationMs <= 0) return 0;
    return (elapsedMs(now) / durationMs).clamp(0.0, 1.0);
  }

  bool get isFinished {
    if (!isCountdown) return false;
    return remainingMs() <= 0 &&
        durationMs > 0 &&
        !isRunning &&
        accumulatedMs >= durationMs;
  }

  ClockTimer copyWith({
    String? name,
    int? accumulatedMs,
    DateTime? runningSince,
    bool clearRunning = false,
    int? durationMs,
    List<int>? laps,
    String? onCompleteStartId,
    bool clearChain = false,
    int? delaySeconds,
    DateTime? delayUntil,
    bool clearDelayUntil = false,
    bool? alertOnDelayEnd,
    String? soundId,
    bool clearSound = false,
  }) {
    return ClockTimer(
      id: id,
      name: name ?? this.name,
      kind: kind,
      accumulatedMs: accumulatedMs ?? this.accumulatedMs,
      runningSince: clearRunning ? null : (runningSince ?? this.runningSince),
      durationMs: durationMs ?? this.durationMs,
      laps: laps ?? this.laps,
      onCompleteStartId:
          clearChain ? null : (onCompleteStartId ?? this.onCompleteStartId),
      delaySeconds: delaySeconds ?? this.delaySeconds,
      delayUntil: clearDelayUntil ? null : (delayUntil ?? this.delayUntil),
      alertOnDelayEnd: alertOnDelayEnd ?? this.alertOnDelayEnd,
      soundId: clearSound ? null : (soundId ?? this.soundId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'accumulatedMs': accumulatedMs,
        'runningSince': runningSince?.toIso8601String(),
        'durationMs': durationMs,
        'laps': laps,
        'onCompleteStartId': onCompleteStartId,
        'delaySeconds': delaySeconds,
        'delayUntil': delayUntil?.toIso8601String(),
        'alertOnDelayEnd': alertOnDelayEnd,
        'soundId': soundId,
      };

  factory ClockTimer.fromJson(Map<String, dynamic> json) {
    return ClockTimer(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Timer',
      kind: (json['kind'] as String?) == 'countdown'
          ? TimerKind.countdown
          : TimerKind.stopwatch,
      accumulatedMs: (json['accumulatedMs'] as num?)?.toInt() ?? 0,
      runningSince: json['runningSince'] is String
          ? DateTime.tryParse(json['runningSince'] as String)
          : null,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      laps: (json['laps'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      onCompleteStartId: json['onCompleteStartId'] as String?,
      delaySeconds: (json['delaySeconds'] as num?)?.toInt() ?? 0,
      delayUntil: json['delayUntil'] is String
          ? DateTime.tryParse(json['delayUntil'] as String)
          : null,
      alertOnDelayEnd: json['alertOnDelayEnd'] as bool? ?? true,
      soundId: json['soundId'] as String?,
    );
  }
}
