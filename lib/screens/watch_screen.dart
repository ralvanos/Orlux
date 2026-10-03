import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/clock_alarm.dart';
import '../models/clock_math.dart';
import '../models/clock_settings.dart';
import '../models/clock_timer.dart';
import '../models/sleep_night.dart';
import '../services/clock_storage.dart';
import '../theme.dart';
import '../widgets/analog_watch_face.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => WatchScreenState();
}

class WatchScreenState extends State<WatchScreen> {
  ClockSettings? _settings;
  DateTime _now = DateTime.now();
  Timer? _ticker;
  bool _tapLock = false;
  List<ClockTimer> _timers = [];
  List<ClockAlarm> _alarms = [];
  SleepStats _sleep = const SleepStats(nights: []);

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final settings = await ClockStorage.getSettings();
    final timers = await ClockStorage.getTimers();
    final alarms = await ClockStorage.getAlarms();
    final sleep = await ClockStorage.getSleepStats();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _timers = timers;
      _alarms = alarms;
      _sleep = sleep;
    });
    await _syncWake();
  }

  Future<void> _syncWake() async {
    final settings = _settings;
    if (settings == null) return;
    if (settings.keepAwake) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  Future<void> _cycleNightDim(ClockSettings settings) async {
    const order = NightDimMode.values;
    final index = order.indexOf(settings.nightDimMode);
    final nextMode = order[(index + 1) % order.length];
    final next = settings.copyWith(nightDimMode: nextMode);
    await ClockStorage.saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _setFace(DisplayMode mode) async {
    final settings = _settings;
    if (settings == null || settings.displayMode == mode) return;
    final next = settings.copyWith(displayMode: mode);
    await ClockStorage.saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Center(
        child: CircularProgressIndicator(color: OrluxColors.aurora),
      );
    }

    final utc = _now.toUtc();
    final local = ClockStorage.wallNow(settings, utc);
    final mode = settings.effectiveDisplayMode;
    final faces = DisplayModeLabel.availableFaces(showUtc: settings.showUtc);
    final dim = settings.nightDimActive(local);
    final showUtcHand = settings.showUtc &&
        (mode == DisplayMode.hybrid || mode == DisplayMode.analog);
    final localColor = dim ? const Color(0xFFC47A4A) : OrluxColors.onInk;
    final utcColor = dim ? const Color(0xFF8A5A28) : OrluxColors.aurora;
    final iceColor = dim ? const Color(0xFFB85C3A) : OrluxColors.ice;

    return ColoredBox(
      color: dim ? const Color(0xFF050302) : OrluxColors.ink,
      child: Stack(
      children: [
        IgnorePointer(
          ignoring: _tapLock,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Orlux',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Night dim: ${settings.nightDimMode.label}',
                        onPressed: () => _cycleNightDim(settings),
                        icon: Icon(
                          dim ? Icons.nights_stay : Icons.nights_stay_outlined,
                          color: iceColor,
                        ),
                      ),
                      IconButton(
                        tooltip: _tapLock ? 'Unlock face' : 'Lock face',
                        onPressed: () => setState(() => _tapLock = !_tapLock),
                        icon: Icon(
                          _tapLock ? Icons.lock : Icons.lock_open_outlined,
                          color: OrluxColors.aurora,
                        ),
                      ),
                    ],
                  ),
                  if (dim)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Night dim · ${settings.nightDimMode.label}',
                        style: TextStyle(
                          color: iceColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (mode == DisplayMode.dual)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _LabeledFace(
                                        label: settings.timezone,
                                        child: AnalogWatchFace(
                                          local: local,
                                          utc: utc,
                                          size: 148,
                                          showUtcHand: false,
                                          dim: dim,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _LabeledFace(
                                        label: 'UTC',
                                        child: AnalogWatchFace(
                                          local: utc,
                                          utc: utc,
                                          size: 148,
                                          showUtcHand: false,
                                          dim: dim,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (mode == DisplayMode.hybrid ||
                                    mode == DisplayMode.analog ||
                                    mode == DisplayMode.analogLocal)
                                  AnalogWatchFace(
                                    local: local,
                                    utc: utc,
                                    size: mode == DisplayMode.hybrid ? 220 : 260,
                                    showUtcHand: showUtcHand,
                                    dim: dim,
                                  ),
                                if (mode == DisplayMode.hybrid ||
                                    mode == DisplayMode.digital ||
                                    mode == DisplayMode.stacked) ...[
                                  const SizedBox(height: 12),
                                  if (mode == DisplayMode.stacked) ...[
                                    Text(
                                      ClockMath.formatClock(
                                        local,
                                        use24Hour: settings.use24Hour,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: localColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      settings.timezone,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: iceColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      ClockMath.formatClock(
                                        utc,
                                        use24Hour: settings.use24Hour,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: utcColor,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'UTC',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: utcColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ] else ...[
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        ClockMath.formatClock(
                                          local,
                                          use24Hour: settings.use24Hour,
                                        ),
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.2,
                                          color: localColor,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Text(
                                      settings.timezone,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: iceColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (settings.showUtc) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'UTC  ${ClockMath.formatClock(
                                          utc,
                                          use24Hour: settings.use24Hour,
                                        )}',
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: utcColor,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  _WatchGlance(
                    now: _now,
                    local: local,
                    settings: settings,
                    timers: _timers,
                    alarms: _alarms,
                    sleep: _sleep,
                    dim: dim,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: faces.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final face = faces[index];
                        return ChoiceChip(
                          label: Text(face.label),
                          selected: mode == face,
                          selectedColor: OrluxColors.aurora,
                          onSelected: (_) => _setFace(face),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        if (_tapLock)
          Positioned(
            right: 16,
            top: 16,
            child: SafeArea(
              child: IconButton.filledTonal(
                onPressed: () => setState(() => _tapLock = false),
                icon: const Icon(Icons.lock),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

class _LabeledFace extends StatelessWidget {
  const _LabeledFace({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        child,
        const SizedBox(height: 6),
        SizedBox(
          width: 148,
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: OrluxColors.ice,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchGlance extends StatelessWidget {
  const _WatchGlance({
    required this.now,
    required this.local,
    required this.settings,
    required this.timers,
    required this.alarms,
    required this.sleep,
    required this.dim,
  });

  final DateTime now;
  final DateTime local;
  final ClockSettings settings;
  final List<ClockTimer> timers;
  final List<ClockAlarm> alarms;
  final SleepStats sleep;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    ClockTimer? live;
    for (final timer in timers) {
      if (timer.isRunning || timer.isDelaying(now)) {
        live = timer;
        break;
      }
    }
    ClockAlarm? nextAlarm;
    DateTime? nextAt;
    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      final wall = alarm.useUtc ? now.toUtc() : local;
      final at = ClockMath.nextAlarmAt(alarm, now: wall);
      if (nextAt == null || at.isBefore(nextAt)) {
        nextAt = at;
        nextAlarm = alarm;
      }
    }
    final latest = sleep.latest;
    final muted = dim
        ? const Color(0xFFB85C3A)
        : Colors.white.withValues(alpha: 0.55);
    final parts = <String>[];
    if (live != null) {
      final delaying = live.isDelaying(now);
      final label = delaying
          ? ClockMath.formatHms(
              Duration(seconds: live.delayRemainingSeconds(now)),
            )
          : ClockMath.formatElapsed(
              live.isCountdown ? live.remainingMs(now) : live.elapsedMs(now),
            );
      parts.add('${live.name} $label');
    }
    if (nextAlarm != null) {
      parts.add(
        'Alarm ${ClockMath.formatHourMinute(nextAlarm.hour, nextAlarm.minute, use24Hour: settings.use24Hour)}',
      );
    }
    if (latest != null) {
      parts.add('Slept ${latest.hours.toStringAsFixed(1)}h');
    }
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      parts.join('  ·  '),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
