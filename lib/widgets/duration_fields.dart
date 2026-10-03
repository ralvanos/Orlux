import 'package:flutter/material.dart';

import '../theme.dart';

class DurationFields extends StatelessWidget {
  const DurationFields({
    super.key,
    required this.duration,
    required this.onChanged,
    this.label = 'Hours, minutes, seconds',
  });

  final Duration duration;
  final ValueChanged<Duration> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hours = duration.inHours.clamp(0, 99).toInt();
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    DropdownButton<int> box({
      required String label,
      required int value,
      required int max,
      required ValueChanged<int> onPick,
    }) {
      return DropdownButton<int>(
        value: value,
        dropdownColor: OrluxColors.card,
        underline: const SizedBox.shrink(),
        items: [
          for (var i = 0; i <= max; i++)
            DropdownMenuItem(value: i, child: Text('$i $label')),
        ],
        onChanged: (next) {
          if (next == null) return;
          onPick(next);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: box(
                label: 'h',
                value: hours,
                max: 99,
                onPick: (h) => onChanged(
                  Duration(hours: h, minutes: minutes, seconds: seconds),
                ),
              ),
            ),
            Expanded(
              child: box(
                label: 'm',
                value: minutes,
                max: 59,
                onPick: (m) => onChanged(
                  Duration(hours: hours, minutes: m, seconds: seconds),
                ),
              ),
            ),
            Expanded(
              child: box(
                label: 's',
                value: seconds,
                max: 59,
                onPick: (s) => onChanged(
                  Duration(hours: hours, minutes: minutes, seconds: s),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
