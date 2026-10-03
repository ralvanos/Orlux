import 'package:flutter/material.dart';

import '../models/sleep_night.dart';
import '../theme.dart';

class SleepStatsCard extends StatelessWidget {
  const SleepStatsCard({
    super.key,
    required this.stats,
    required this.onBedtime,
    required this.onWake,
    this.onResetBedtime,
    this.bedtimeSet = false,
    this.goalHours = 7.5,
  });

  final SleepStats stats;
  final VoidCallback onBedtime;
  final VoidCallback onWake;
  final VoidCallback? onResetBedtime;
  final bool bedtimeSet;
  final double goalHours;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageHours;
    final latest = stats.latest;
    final bars = stats.last14;
    final recent = bars.reversed.take(7).toList();
    return Material(
      color: OrluxColors.card,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sleep trends',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              average == null
                  ? bedtimeSet
                      ? 'Bedtime is marked. Tap I’m up when you get out of bed to log this night.'
                      : 'Tap Going to bed when you lie down. Hours appear here after you tap I’m up or stop the alarm.'
                  : 'Average ${average.toStringAsFixed(1)} h  ·  goal ${goalHours.toStringAsFixed(1)} h  ·  last ${bars.length} night${bars.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            if (latest != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last night ${latest.hours.toStringAsFixed(1)} h${latest.skipped ? ' · skipped alarm' : ''}',
                style: const TextStyle(color: OrluxColors.ice, fontSize: 13),
              ),
            ],
            if (bars.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final night in bars) ...[
                      Expanded(
                        child: Container(
                          height: (night.hours / 10).clamp(0.08, 1.0) * 72,
                          decoration: BoxDecoration(
                            color: night.skipped
                                ? OrluxColors.aurora.withValues(alpha: 0.45)
                                : night.meetsGoal(goalHours)
                                    ? OrluxColors.mint
                                    : OrluxColors.ice.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              for (final night in recent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          night.shortLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        '${night.hours.toStringAsFixed(1)} h'
                        '${night.skipped ? ' · skipped' : ''}',
                        style: const TextStyle(
                          color: OrluxColors.onInk,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            if (bedtimeSet)
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: onWake,
                      child: const Text('I’m up'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onResetBedtime ?? onBedtime,
                      child: const Text('Reset bedtime'),
                    ),
                  ),
                ],
              )
            else
              FilledButton.tonal(
                onPressed: onBedtime,
                child: const Text('Going to bed'),
              ),
          ],
        ),
      ),
    );
  }
}
