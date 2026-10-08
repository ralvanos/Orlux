import 'dart:async';

import 'package:flutter/material.dart';

import '../models/clock_math.dart';
import '../models/clock_timer.dart';
import '../services/clock_storage.dart';
import '../theme.dart';
import '../widgets/alert_sound_picker.dart';
import '../widgets/duration_fields.dart';
import '../widgets/edit_sheet_scaffold.dart';
import '../widgets/timer_presets.dart';
import '../widgets/timer_progress_ring.dart';

class TimersScreen extends StatefulWidget {
  const TimersScreen({super.key});

  @override
  State<TimersScreen> createState() => TimersScreenState();
}

class TimersScreenState extends State<TimersScreen> {
  List<ClockTimer> _timers = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    reload();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) async {
      if (!mounted) return;
      final settled = await ClockStorage.settleCompleted();
      if (!mounted) return;
      setState(() => _timers = settled);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    final timers = await ClockStorage.getTimers();
    if (!mounted) return;
    setState(() => _timers = timers);
  }

  Future<void> _start(ClockTimer timer) async {
    await ClockStorage.startTimer(timer);
    await reload();
  }

  Future<void> _addPreset(Duration duration) async {
    await ClockStorage.upsertTimer(
      ClockTimer(
        id: ClockStorage.newId(),
        name: TimerPresets.name(duration),
        kind: TimerKind.countdown,
        durationMs: duration.inMilliseconds,
      ),
    );
    await reload();
  }

  Future<void> _pickAdd() async {
    if (!mounted) return;
    await _edit();
  }

  Future<void> _edit({ClockTimer? existing, TimerKind? kind}) async {
    final chainOptions = _timers.where((t) => t.id != existing?.id).toList();
    final result = await showModalBottomSheet<_TimerDraft>(
      context: context,
      backgroundColor: OrluxColors.card,
      isScrollControlled: true,
      useSafeArea: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _TimerEditSheet(
          existing: existing,
          kind: existing?.kind ?? kind ?? TimerKind.stopwatch,
          nextIndex: _timers.length + 1,
          chainOptions: chainOptions,
        );
      },
    );
    if (result == null) return;
    final savedKind = result.kind;
    if (existing == null) {
      await ClockStorage.upsertTimer(
        ClockTimer(
          id: ClockStorage.newId(),
          name: result.name,
          kind: savedKind,
          durationMs: savedKind == TimerKind.countdown
              ? result.duration.inMilliseconds
              : 0,
          delaySeconds: result.delay.inSeconds,
          alertOnDelayEnd: result.alertOnDelayEnd,
          onCompleteStartId: result.chainId,
          soundId: result.soundId,
        ),
      );
    } else {
      await ClockStorage.upsertTimer(
        existing.copyWith(
          name: result.name,
          durationMs: savedKind == TimerKind.countdown
              ? result.duration.inMilliseconds
              : 0,
          delaySeconds: result.delay.inSeconds,
          alertOnDelayEnd: result.alertOnDelayEnd,
          onCompleteStartId: result.chainId,
          clearChain: result.chainId == null,
          clearDelayUntil: result.delay.inSeconds == 0,
          soundId: result.soundId,
          clearSound: result.soundId == null,
        ),
      );
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
                    'Timers',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Add stopwatch or countdown',
                  onPressed: _pickAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
            child: Row(
              children: [
                Text(
                  'Quick countdown',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: TimerPresetChips(
                      selected: null,
                      onSelected: _addPreset,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_timers.any((t) => t.isDelaying()))
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Waiting to start',
                style: TextStyle(
                  color: OrluxColors.aurora.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: _timers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Add a stopwatch or countdown.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _pickAdd,
                            icon: const Icon(Icons.add),
                            label: const Text('Add timer'),
                            style: FilledButton.styleFrom(
                              backgroundColor: OrluxColors.aurora,
                              foregroundColor: const Color(0xFF1A1408),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _timers.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _TimerCard(
                        timer: _timers[index],
                        now: DateTime.now(),
                        onStart: () async {
                          final timer = _timers[index];
                          if (timer.isRunning || timer.isDelaying()) {
                            await ClockStorage.stopTimer(timer);
                          } else {
                            await _start(timer);
                          }
                          await reload();
                        },
                        onReset: () async {
                          await ClockStorage.resetTimer(_timers[index]);
                          await reload();
                        },
                        onLap: () async {
                          await ClockStorage.lapTimer(_timers[index]);
                          await reload();
                        },
                        onEdit: () => _edit(existing: _timers[index]),
                        onDelete: () async {
                          await ClockStorage.deleteTimer(_timers[index].id);
                          await reload();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.timer,
    required this.now,
    required this.onStart,
    required this.onReset,
    required this.onLap,
    required this.onEdit,
    required this.onDelete,
  });

  final ClockTimer timer;
  final DateTime now;
  final VoidCallback onStart;
  final VoidCallback onReset;
  final VoidCallback onLap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final delaying = timer.isDelaying(now);
    final showRing = timer.isCountdown || delaying;
    final ringColor = delaying
        ? OrluxColors.aurora
        : timer.isFinished
            ? OrluxColors.ice
            : OrluxColors.mint;
    final display = ClockMath.formatElapsed(timer.displayMs(now));

    return Material(
      color: OrluxColors.card,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    timer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  delaying
                      ? 'Delay'
                      : timer.isFinished
                          ? 'Done'
                          : timer.isCountdown
                              ? 'Countdown'
                              : 'Stopwatch',
                  style: TextStyle(
                    color: delaying
                        ? OrluxColors.aurora
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showRing) ...[
                  TimerProgressRing(
                    progress: timer.progress(now),
                    color: ringColor,
                    size: 72,
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (timer.isCountdown)
                        Text(
                          delaying
                              ? 'Starts after delay${timer.alertOnDelayEnd ? ' · will alert' : ''}'
                              : 'Set for ${ClockMath.formatHms(Duration(milliseconds: timer.durationMs))}',
                          style: TextStyle(
                            color: delaying
                                ? OrluxColors.aurora
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: (timer.isRunning || delaying)
                        ? OrluxColors.danger
                        : OrluxColors.mint,
                    foregroundColor: const Color(0xFF08140F),
                  ),
                  child: Text(
                    delaying
                        ? 'Cancel'
                        : timer.isRunning
                            ? 'Stop'
                            : 'Start',
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
                if (timer.kind == TimerKind.stopwatch && timer.isRunning) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onLap,
                    child: const Text('Lap'),
                  ),
                ],
              ],
            ),
            if (timer.laps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  timer.laps
                      .asMap()
                      .entries
                      .map(
                        (e) =>
                            'L${e.key + 1} ${ClockMath.formatElapsed(e.value)}',
                      )
                      .join('  ·  '),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimerDraft {
  const _TimerDraft({
    required this.name,
    required this.kind,
    required this.duration,
    required this.delay,
    required this.alertOnDelayEnd,
    required this.chainId,
    required this.soundId,
  });

  final String name;
  final TimerKind kind;
  final Duration duration;
  final Duration delay;
  final bool alertOnDelayEnd;
  final String? chainId;
  final String? soundId;
}

class _TimerEditSheet extends StatefulWidget {
  const _TimerEditSheet({
    required this.existing,
    required this.kind,
    required this.nextIndex,
    required this.chainOptions,
  });

  final ClockTimer? existing;
  final TimerKind kind;
  final int nextIndex;
  final List<ClockTimer> chainOptions;

  @override
  State<_TimerEditSheet> createState() => _TimerEditSheetState();
}

class _TimerEditSheetState extends State<_TimerEditSheet> {
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;
  late TimerKind _kind;
  late Duration _duration;
  late Duration _delay;
  late bool _alertOnDelayEnd;
  String? _chainId;
  String? _soundId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _kind = existing?.kind ?? widget.kind;
    _nameCtrl = TextEditingController(
      text: existing?.name ??
          (_kind == TimerKind.stopwatch
              ? 'Stopwatch ${widget.nextIndex}'
              : 'Countdown ${widget.nextIndex}'),
    );
    _nameFocus = FocusNode();
    _duration = Duration(
      milliseconds:
          existing?.durationMs ?? const Duration(minutes: 5).inMilliseconds,
    );
    if (existing == null &&
        _kind == TimerKind.countdown &&
        _duration.inSeconds == 0) {
      _duration = const Duration(minutes: 5);
    }
    _delay = Duration(seconds: existing?.delaySeconds ?? 0);
    _alertOnDelayEnd = existing?.alertOnDelayEnd ?? true;
    _chainId = existing?.onCompleteStartId;
    _soundId = existing?.soundId;
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setKind(TimerKind kind) {
    if (_kind == kind) return;
    final oldDefault = _kind == TimerKind.stopwatch
        ? 'Stopwatch ${widget.nextIndex}'
        : 'Countdown ${widget.nextIndex}';
    setState(() {
      _kind = kind;
      if (_nameCtrl.text == oldDefault) {
        _nameCtrl.text = kind == TimerKind.stopwatch
            ? 'Stopwatch ${widget.nextIndex}'
            : 'Countdown ${widget.nextIndex}';
        _nameCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nameCtrl.text.length,
        );
      }
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (_kind == TimerKind.countdown && _duration.inSeconds < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set at least 1 second.')),
      );
      return;
    }
    Navigator.pop(
      context,
      _TimerDraft(
        name: name.isEmpty
            ? (_kind == TimerKind.stopwatch ? 'Stopwatch' : 'Countdown')
            : name,
        kind: _kind,
        duration: _duration,
        delay: _delay,
        alertOnDelayEnd: _alertOnDelayEnd,
        chainId: _chainId,
        soundId: _soundId,
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
          Text(
            widget.existing == null
                ? 'New timer'
                : 'Edit ${_kind == TimerKind.stopwatch ? 'stopwatch' : 'countdown'}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          if (widget.existing == null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Stopwatch'),
                  selected: _kind == TimerKind.stopwatch,
                  selectedColor: OrluxColors.aurora,
                  onSelected: (_) => _setKind(TimerKind.stopwatch),
                ),
                ChoiceChip(
                  label: const Text('Countdown'),
                  selected: _kind == TimerKind.countdown,
                  selectedColor: OrluxColors.aurora,
                  onSelected: (_) => _setKind(TimerKind.countdown),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            autofocus: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          AlertSoundPicker(
            soundId: _soundId,
            showImport: true,
            onChanged: (id) => setState(() => _soundId = id),
          ),
          if (_kind == TimerKind.countdown) ...[
            const SizedBox(height: 8),
            const Text('Presets'),
            const SizedBox(height: 8),
            TimerPresetChips(
              selected: _duration,
              onSelected: (preset) => setState(() => _duration = preset),
            ),
            const SizedBox(height: 12),
            DurationFields(
              duration: _duration,
              label: 'Duration',
              onChanged: (next) => setState(() => _duration = next),
            ),
          ],
          const SizedBox(height: 8),
          DurationFields(
            duration: _delay,
            label: 'Delayed start',
            onChanged: (next) => setState(() => _delay = next),
          ),
          Text(
            _delay.inSeconds == 0
                ? 'Starts as soon as you press Start.'
                : 'Waits ${ClockMath.formatHms(_delay)} after Start.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          if (_delay.inSeconds > 0)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _alertOnDelayEnd,
              activeThumbColor: OrluxColors.aurora,
              title: const Text('Alert when delay ends'),
              subtitle: const Text(
                'Sound, haptic, and a notification when the timer actually starts.',
              ),
              onChanged: (v) => setState(() => _alertOnDelayEnd = v),
            ),
          if (_kind == TimerKind.countdown && widget.chainOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _chainId,
              dropdownColor: OrluxColors.card,
              decoration: const InputDecoration(
                labelText: 'When finished, start',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Nothing'),
                ),
                for (final t in widget.chainOptions)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(t.name),
                  ),
              ],
              onChanged: (v) => setState(() => _chainId = v),
            ),
          ],
        ],
      ),
    );
  }
}
