import 'package:flutter/material.dart';

import '../models/clock_alarm.dart';
import '../models/clock_math.dart';
import '../services/alarm_ring.dart';
import '../services/clock_storage.dart';
import '../theme.dart';
import 'wake_code_pad.dart';

class AlarmRingOverlay extends StatelessWidget {
  const AlarmRingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AlarmRing.instance.ringing,
      builder: (context, alarm, _) {
        if (alarm == null) return const SizedBox.shrink();
        return FutureBuilder(
          future: ClockStorage.getSettings(),
          builder: (context, snap) {
            final settings = snap.data;
            final use24 = settings?.use24Hour ?? true;
            return _AlarmRingSheet(alarm: alarm, use24Hour: use24);
          },
        );
      },
    );
  }
}

class _AlarmRingSheet extends StatefulWidget {
  const _AlarmRingSheet({
    required this.alarm,
    required this.use24Hour,
  });

  final ClockAlarm alarm;
  final bool use24Hour;

  @override
  State<_AlarmRingSheet> createState() => _AlarmRingSheetState();
}

class _AlarmRingSheetState extends State<_AlarmRingSheet> {
  bool _code = false;

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final time = ClockMath.formatHourMinute(
      alarm.hour,
      alarm.minute,
      use24Hour: widget.use24Hour,
    );
    final snoozeOn = alarm.snoozeMinutes > 0;
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _code
                ? WakeCodePad(
                    onSolved: () => ClockStorage.stopRingingAlarm(),
                    onCancel: () => setState(() => _code = false),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.alarm,
                        size: 52,
                        color: OrluxColors.aurora,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        time,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: OrluxColors.onInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alarm.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: OrluxColors.ice,
                        ),
                      ),
                      const SizedBox(height: 28),
                      if (snoozeOn)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    ClockStorage.snoozeRingingAlarm(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: OrluxColors.onInk,
                                  side: const BorderSide(color: OrluxColors.ice),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text('Snooze ${alarm.snoozeMinutes}m'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  if (alarm.wakeCode) {
                                    setState(() => _code = true);
                                  } else {
                                    ClockStorage.stopRingingAlarm();
                                  }
                                },
                                style: FilledButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: Text(
                                  alarm.wakeCode ? 'Stop with code' : 'Stop',
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (alarm.wakeCode) {
                                setState(() => _code = true);
                              } else {
                                ClockStorage.stopRingingAlarm();
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              alarm.wakeCode ? 'Stop with code' : 'Stop',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
