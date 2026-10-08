import 'package:flutter/material.dart';

import '../models/clock_alarm.dart';
import '../models/clock_math.dart';
import '../models/clock_settings.dart';
import '../models/sleep_night.dart';
import '../services/clock_storage.dart';
import '../theme.dart';
import '../widgets/alert_sound_picker.dart';
import '../widgets/edit_sheet_scaffold.dart';
import '../widgets/sleep_edit_sheet.dart';
import '../widgets/sleep_stats_card.dart';
import '../widgets/wake_code_pad.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => AlarmsScreenState();
}

class AlarmsScreenState extends State<AlarmsScreen> {
  List<ClockAlarm> _alarms = [];
  bool _use24Hour = true;
  SleepStats _sleep = const SleepStats(nights: []);
  int? _bedtimeMs;
  ClockSettings? _settings;

  static const _days = [
    (DateTime.monday, 'Mon'),
    (DateTime.tuesday, 'Tue'),
    (DateTime.wednesday, 'Wed'),
    (DateTime.thursday, 'Thu'),
    (DateTime.friday, 'Fri'),
    (DateTime.saturday, 'Sat'),
    (DateTime.sunday, 'Sun'),
  ];

  static const _snoozeMinutes = [0, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    ClockStorage.sleepRevision.addListener(_onSleepChanged);
    reload();
  }

  @override
  void dispose() {
    ClockStorage.sleepRevision.removeListener(_onSleepChanged);
    super.dispose();
  }

  void _onSleepChanged() {
    reload();
  }

  Future<void> reload() async {
    final alarms = await ClockStorage.getAlarms();
    final settings = await ClockStorage.getSettings();
    final sleep = await ClockStorage.getSleepStats();
    final bedtime = await ClockStorage.pendingBedtimeMs();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _settings = settings;
      _use24Hour = settings.use24Hour;
      _sleep = sleep;
      _bedtimeMs = bedtime;
    });
  }

  Future<void> _edit([ClockAlarm? existing]) async {
    final result = await showModalBottomSheet<ClockAlarm>(
      context: context,
      backgroundColor: OrluxColors.card,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _AlarmEditSheet(
          initial: existing ??
              ClockAlarm(
                id: ClockStorage.newId(),
                label: 'Alarm ${_alarms.length + 1}',
                hour: 7,
                minute: 0,
              ),
          use24Hour: _use24Hour,
          focusLabel: existing != null,
        );
      },
    );
    if (result == null) return;
    await ClockStorage.upsertAlarm(result);
    await reload();
    if (!mounted || !result.enabled) return;
    final message = await ClockStorage.alarmSetMessage(result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editSleep([SleepNight? existing]) async {
    final result = await showModalBottomSheet<SleepNightEdit>(
      context: context,
      backgroundColor: OrluxColors.card,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SleepEditSheet(
          existing: existing,
          use24Hour: _use24Hour,
          takenDateKeys: _sleep.nights.map((night) => night.dateKey).toSet(),
        );
      },
    );
    if (result == null) return;
    if (result.deleted) {
      final key = result.dateKey;
      if (key != null) await ClockStorage.deleteSleepNight(key);
    } else if (result.night != null) {
      await ClockStorage.upsertSleepNight(result.night!);
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Alarms',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: _alarms.isEmpty &&
                    !_alarms.any((a) => a.trackSleep) &&
                    _sleep.nights.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alarm_outlined,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Set as many alarm times as you need.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _alarms.length +
                        (_sleep.nights.isNotEmpty ||
                                _alarms.any((a) => a.trackSleep)
                            ? 1
                            : 0),
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final showSleep = _sleep.nights.isNotEmpty ||
                          _alarms.any((a) => a.trackSleep);
                      if (showSleep && index == 0) {
                        return SleepStatsCard(
                          stats: _sleep,
                          bedtimeSet: (_bedtimeMs ?? 0) > 0,
                          goalHours: _settings?.sleepGoalHours ?? 7.5,
                          use24Hour: _use24Hour,
                          onEditNight: _editSleep,
                          onAddNight: () => _editSleep(),
                          onBedtime: () async {
                            await ClockStorage.markBedtime();
                            await reload();
                          },
                          onResetBedtime: () async {
                            await ClockStorage.clearBedtime();
                            await reload();
                          },
                          onWake: () async {
                            final result = await ClockStorage.wakeUp();
                            await reload();
                            if (!context.mounted) return;
                            final night = result.night;
                            final String message;
                            if (night == null) {
                              message =
                                  'Mark Going to bed first, then tap I’m up in the morning.';
                            } else if (result.stoppedRinging &&
                                result.silencedAlarm) {
                              message =
                                  'Logged ${night.hours.toStringAsFixed(1)} hours. Alarm stopped, and the others set for today are off.';
                            } else if (result.stoppedRinging) {
                              message =
                                  'Logged ${night.hours.toStringAsFixed(1)} hours. Alarm stopped.';
                            } else if (night.skipped) {
                              message =
                                  'Logged ${night.hours.toStringAsFixed(1)} hours. Alarms set for today are off, and this night is marked skipped.';
                            } else {
                              message =
                                  'Logged ${night.hours.toStringAsFixed(1)} hours. Trends are on this card.';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          },
                        );
                      }
                      final alarmIndex = (_sleep.nights.isNotEmpty ||
                              _alarms.any((a) => a.trackSleep))
                          ? index - 1
                          : index;
                      final alarm = _alarms[alarmIndex];
                      final days = alarm.days.isEmpty
                          ? 'Once'
                          : _days
                              .where((d) => alarm.days.contains(d.$1))
                              .map((d) => d.$2)
                              .join(' ');
                      final settings = _settings;
                      final skipToday = settings != null &&
                          ClockStorage.canSkipToday(alarm, settings);
                      return Material(
                        color: OrluxColors.card,
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListTile(
                                onTap: () => _edit(alarm),
                                title: Text(
                                  ClockMath.formatHourMinute(
                                    alarm.hour,
                                    alarm.minute,
                                    use24Hour: _use24Hour,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${alarm.label} · $days${alarm.useUtc ? ' · UTC' : ''}'
                                  '${alarm.snoozeMinutes > 0 ? ' · snooze ${alarm.snoozeMinutes}m' : ''}'
                                  '${alarm.skipFederalHolidays ? ' · skip holidays' : ''}'
                                  '${alarm.wakeCode ? ' · wake code' : ''}'
                                  '${alarm.trackSleep ? ' · sleep' : ''}'
                                  '${alarm.skipDate != null ? ' · skipped ${alarm.skipDate}' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch.adaptive(
                                      value: alarm.enabled,
                                      activeThumbColor: OrluxColors.aurora,
                                      onChanged: (v) async {
                                        final next = alarm.copyWith(enabled: v);
                                        await ClockStorage.upsertAlarm(next);
                                        await reload();
                                        if (!v || !context.mounted) return;
                                        final message =
                                            await ClockStorage.alarmSetMessage(
                                          next,
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(message)),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      onPressed: () async {
                                        await ClockStorage.deleteAlarm(
                                          alarm.id,
                                        );
                                        await reload();
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                              if (skipToday)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 4),
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await ClockStorage.skipToday(alarm);
                                      await reload();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Skipped today. The next alarm stays on.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Skip today · already up'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlarmEditSheet extends StatefulWidget {
  const _AlarmEditSheet({
    required this.initial,
    required this.use24Hour,
    this.focusLabel = false,
  });

  final ClockAlarm initial;
  final bool use24Hour;
  final bool focusLabel;

  @override
  State<_AlarmEditSheet> createState() => _AlarmEditSheetState();
}

class _AlarmEditSheetState extends State<_AlarmEditSheet> {
  late ClockAlarm _alarm;
  late final TextEditingController _label;
  late final FocusNode _labelFocus;

  @override
  void initState() {
    super.initState();
    _alarm = widget.initial;
    _label = TextEditingController(text: _alarm.label);
    _labelFocus = FocusNode();
    if (widget.focusLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 280), () {
          if (!mounted) return;
          _labelFocus.requestFocus();
          _label.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _label.text.length,
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _labelFocus.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _alarm.copyWith(
        label: _label.text.trim().isEmpty ? _alarm.label : _label.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditSheetScaffold(
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Alarm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            focusNode: _labelFocus,
            autofocus: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          AlertSoundPicker(
            soundId: _alarm.soundId,
            showImport: true,
            onChanged: (id) => setState(() {
              _alarm = _alarm.copyWith(
                soundId: id,
                clearSound: id == null,
              );
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Time'),
            subtitle: Text(
              ClockMath.formatHourMinute(
                _alarm.hour,
                _alarm.minute,
                use24Hour: widget.use24Hour,
              ),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: _alarm.hour,
                  minute: _alarm.minute,
                ),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      alwaysUse24HourFormat: widget.use24Hour,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
              if (picked == null) return;
              setState(() {
                _alarm = _alarm.copyWith(
                  hour: picked.hour,
                  minute: picked.minute,
                );
              });
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _alarm.useUtc,
            activeThumbColor: OrluxColors.aurora,
            title: const Text('Use UTC'),
            subtitle: const Text('Off = your selected timezone'),
            onChanged: (v) => setState(() {
              _alarm = _alarm.copyWith(useUtc: v);
            }),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _alarm.skipFederalHolidays,
            activeThumbColor: OrluxColors.aurora,
            title: const Text('Skip U.S. federal holidays'),
            subtitle: const Text(
              'If the time falls on a holiday, wait until the next business day.',
            ),
            onChanged: (v) => setState(() {
              _alarm = _alarm.copyWith(skipFederalHolidays: v);
            }),
          ),
          const Text('Snooze'),
          Wrap(
            spacing: 8,
            children: [
              for (final minutes in AlarmsScreenState._snoozeMinutes)
                ChoiceChip(
                  label: Text(minutes == 0 ? 'Off' : '${minutes}m'),
                  selected: _alarm.snoozeMinutes == minutes,
                  selectedColor: OrluxColors.aurora,
                  onSelected: (_) => setState(() {
                    _alarm = _alarm.copyWith(snoozeMinutes: minutes);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _alarm.wakeCode,
            activeThumbColor: OrluxColors.aurora,
            title: const Text('Wake code to stop'),
            subtitle: const Text(
              'Four random digits on a shuffled keypad. Fast, and it does not become muscle memory.',
            ),
            onChanged: (v) => setState(() {
              _alarm = _alarm.copyWith(wakeCode: v);
            }),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => WakeCodePad.showPractice(context),
              icon: const Icon(Icons.pin_outlined, size: 18),
              label: const Text('Try wake code'),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _alarm.trackSleep,
            activeThumbColor: OrluxColors.aurora,
            title: const Text('Track sleep'),
            subtitle: const Text(
              'Logs hours from Going to bed until you tap I’m up or stop this alarm. I’m up turns off alarms still set for today.',
            ),
            onChanged: (v) => setState(() {
              _alarm = _alarm.copyWith(trackSleep: v);
            }),
          ),
          if (_alarm.trackSleep)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Usual bedtime'),
              subtitle: Text(
                ClockMath.formatHourMinute(
                  _alarm.bedtimeHour,
                  _alarm.bedtimeMinute,
                  use24Hour: widget.use24Hour,
                ),
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                    hour: _alarm.bedtimeHour,
                    minute: _alarm.bedtimeMinute,
                  ),
                  builder: (context, child) {
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        alwaysUse24HourFormat: widget.use24Hour,
                      ),
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked == null) return;
                setState(() {
                  _alarm = _alarm.copyWith(
                    bedtimeHour: picked.hour,
                    bedtimeMinute: picked.minute,
                  );
                });
              },
            ),
          const Text('Repeat'),
          Wrap(
            spacing: 6,
            children: [
              for (final day in AlarmsScreenState._days)
                FilterChip(
                  label: Text(day.$2),
                  selected: _alarm.days.contains(day.$1),
                  selectedColor: OrluxColors.aurora,
                  onSelected: (on) {
                    final next = [..._alarm.days];
                    if (on) {
                      next.add(day.$1);
                    } else {
                      next.remove(day.$1);
                    }
                    setState(() => _alarm = _alarm.copyWith(days: next));
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
