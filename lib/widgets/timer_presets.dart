import 'package:flutter/material.dart';

import '../theme.dart';

class TimerPresets {
  TimerPresets._();

  static const values = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 25),
  ];

  static String label(Duration d) {
    if (d.inSeconds.remainder(60) != 0) {
      return '${d.inSeconds}s';
    }
    if (d.inMinutes.remainder(60) == 0 && d.inHours > 0) {
      return '${d.inHours}h';
    }
    return '${d.inMinutes}m';
  }

  static String name(Duration d) => '${label(d)} countdown';
}

class TimerPresetChips extends StatelessWidget {
  const TimerPresetChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final Duration? selected;
  final ValueChanged<Duration> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preset in TimerPresets.values)
          ChoiceChip(
            label: Text(TimerPresets.label(preset)),
            selected: selected == preset,
            selectedColor: OrluxColors.aurora,
            onSelected: (_) => onSelected(preset),
          ),
      ],
    );
  }
}
