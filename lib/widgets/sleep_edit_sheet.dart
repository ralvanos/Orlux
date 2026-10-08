import 'package:flutter/material.dart';

import '../models/clock_math.dart';
import '../models/sleep_night.dart';
import '../theme.dart';
import 'edit_sheet_scaffold.dart';

class SleepNightEdit {
  const SleepNightEdit.saved(this.night)
      : deleted = false,
        dateKey = null;

  const SleepNightEdit.deleted(this.dateKey)
      : night = null,
        deleted = true;

  final SleepNight? night;
  final String? dateKey;
  final bool deleted;
}

class SleepEditSheet extends StatefulWidget {
  const SleepEditSheet({
    super.key,
    required this.use24Hour,
    required this.takenDateKeys,
    this.existing,
  });

  final SleepNight? existing;
  final bool use24Hour;
  final Set<String> takenDateKeys;

  @override
  State<SleepEditSheet> createState() => _SleepEditSheetState();
}

class _StretchDraft {
  _StretchDraft({required this.start, required this.end});

  TimeOfDay start;
  TimeOfDay end;
}

class _SleepEditSheetState extends State<SleepEditSheet> {
  late DateTime _wakeDay;
  late bool _skipped;
  late final List<_StretchDraft> _stretches;
  String? _alarmId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _skipped = existing?.skipped ?? false;
    _alarmId = existing?.alarmId;
    final today = DateTime.now();
    _wakeDay = existing == null
        ? DateTime(today.year, today.month, today.day)
        : (SleepNight.dateOf(existing.dateKey) ??
            DateTime(today.year, today.month, today.day));
    final spans = existing?.resolvedSpans ?? const <SleepSpan>[];
    if (spans.isEmpty) {
      _stretches = [
        _StretchDraft(
          start: const TimeOfDay(hour: 23, minute: 0),
          end: const TimeOfDay(hour: 7, minute: 0),
        ),
      ];
    } else {
      _stretches = [
        for (final span in spans)
          _StretchDraft(
            start: TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(span.startMs),
            ),
            end: TimeOfDay.fromDateTime(
              DateTime.fromMillisecondsSinceEpoch(span.endMs),
            ),
          ),
      ];
    }
  }

  String get _dateKey => ClockMath.dateKey(_wakeDay);

  List<SleepSpan?> get _aligned {
    return [
      for (final stretch in _stretches)
        SleepSpan.onWakeDay(
          wakeDay: _wakeDay,
          startHour: stretch.start.hour,
          startMinute: stretch.start.minute,
          endHour: stretch.end.hour,
          endMinute: stretch.end.minute,
        ),
    ];
  }

  SleepNight? get _preview {
    final placed = [for (final span in _aligned) if (span != null) span];
    if (placed.isEmpty || placed.length != _stretches.length) return null;
    final merged = SleepSpan.merge(placed);
    var minutes = 0;
    for (final span in merged) {
      minutes += span.minutes;
    }
    if (minutes < 1 || minutes > 24 * 60) return null;
    return SleepNight.fromSpans(
      dateKey: _dateKey,
      spans: placed,
      alarmId: _alarmId,
      skipped: _skipped,
    );
  }

  Future<void> _pickTime(_StretchDraft stretch, {required bool start}) async {
    final current = start ? stretch.start : stretch.end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
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
      if (start) {
        stretch.start = picked;
      } else {
        stretch.end = picked;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _wakeDay.isAfter(today) ? today : _wakeDay,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _wakeDay = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _addStretch() {
    final last = _stretches.last.end;
    setState(() {
      _stretches.add(
        _StretchDraft(
          start: _shift(last, 120),
          end: _shift(last, 240),
        ),
      );
    });
  }

  TimeOfDay _shift(TimeOfDay time, int minutes) {
    final total = (time.hour * 60 + time.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  void _save() {
    if (widget.existing == null && widget.takenDateKeys.contains(_dateKey)) {
      _toast('That morning is already logged. Tap it in the list to edit.');
      return;
    }
    final preview = _preview;
    if (preview == null) {
      final placed = [for (final span in _aligned) if (span != null) span];
      if (placed.length != _stretches.length) {
        _toast('Each stretch needs an end time after the start.');
        return;
      }
      _toast('Sleep has to be between 1 minute and 24 hours.');
      return;
    }
    Navigator.pop(context, SleepNightEdit.saved(preview));
  }

  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OrluxColors.card,
        title: const Text('Remove this night?'),
        content: const Text('This removes the logged hours for this morning.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.pop(context, SleepNightEdit.deleted(existing.dateKey));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _stamp(DateTime dt) {
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
    return '${months[dt.month - 1]} ${dt.day}, ${ClockMath.formatHm(dt, use24Hour: widget.use24Hour)}';
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final preview = _preview;
    final mergedCount = preview?.resolvedSpans.length ?? 0;
    final label = existing?.shortLabel ?? ClockMath.dateKey(_wakeDay);
    return EditSheetScaffold(
      onSave: _save,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            existing == null ? 'Log a night' : 'Edit $label',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Set when you fell asleep and when you woke. If you were up in the middle of the night, add another stretch so that time is not counted.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Morning you woke'),
            subtitle: Text(existing?.shortLabel ?? _prettyDay(_wakeDay)),
            trailing: existing == null ? const Icon(Icons.chevron_right) : null,
            onTap: existing == null ? _pickDate : null,
          ),
          for (var i = 0; i < _stretches.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    _stretches.length == 1 ? 'Asleep' : 'Stretch ${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_stretches.length > 1)
                  IconButton(
                    tooltip: 'Remove stretch',
                    onPressed: () => setState(() => _stretches.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'Fell asleep',
                    value: ClockMath.formatHourMinute(
                      _stretches[i].start.hour,
                      _stretches[i].start.minute,
                      use24Hour: widget.use24Hour,
                    ),
                    onTap: () => _pickTime(_stretches[i], start: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeButton(
                    label: 'Woke',
                    value: ClockMath.formatHourMinute(
                      _stretches[i].end.hour,
                      _stretches[i].end.minute,
                      use24Hour: widget.use24Hour,
                    ),
                    onTap: () => _pickTime(_stretches[i], start: false),
                  ),
                ),
              ],
            ),
            if (_aligned[i] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  '${_stamp(DateTime.fromMillisecondsSinceEpoch(_aligned[i]!.startMs))} – ${_stamp(DateTime.fromMillisecondsSinceEpoch(_aligned[i]!.endMs))}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addStretch,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Awake, then back to bed'),
            ),
          ),
          Text(
            'A start from noon onward counts as the evening before this morning.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            preview == null
                ? 'Set a start and end for each stretch.'
                : '${preview.hours.toStringAsFixed(1)} h asleep'
                    '${mergedCount < _stretches.length ? ' · overlapping stretches are combined' : ''}',
            style: const TextStyle(
              color: OrluxColors.ice,
              fontWeight: FontWeight.w700,
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _skipped,
            activeThumbColor: OrluxColors.aurora,
            title: const Text('Skipped alarm'),
            subtitle: const Text(
              'On when you woke before the alarm and turned it off.',
            ),
            onChanged: (value) => setState(() => _skipped = value),
          ),
          if (existing != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _confirmDelete,
                child: const Text('Remove this night'),
              ),
            ),
        ],
      ),
    );
  }

  String _prettyDay(DateTime day) {
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
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OrluxColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
