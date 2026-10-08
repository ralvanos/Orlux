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
    this.onEditNight,
    this.onAddNight,
    this.bedtimeSet = false,
    this.goalHours = 7.5,
    this.use24Hour = true,
  });

  final SleepStats stats;
  final VoidCallback onBedtime;
  final VoidCallback onWake;
  final VoidCallback? onResetBedtime;
  final void Function(SleepNight night)? onEditNight;
  final VoidCallback? onAddNight;
  final bool bedtimeSet;
  final double goalHours;
  final bool use24Hour;

  @override
  Widget build(BuildContext context) {
    final average = stats.averageHours;
    final latest = stats.latest;
    final bars = stats.chronological;
    final rows = stats.last7.reversed.toList();
    final averaged = stats.last14.length;
    final gap = bars.length > 21 ? 1.0 : 3.0;
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
                      ? 'Bedtime is marked. I’m up logs this night, turns off alarms still set for today, and marks it skipped.'
                      : 'Tap Going to bed when you lie down. Hours appear here after you tap I’m up or stop the alarm.'
                  : 'Average ${average.toStringAsFixed(1)} h  ·  goal ${goalHours.toStringAsFixed(1)} h  ·  last $averaged night${averaged == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            if (latest != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last night ${latest.hours.toStringAsFixed(1)} h'
                '${latest.rangesLabel(use24Hour: use24Hour).isEmpty ? '' : ' · ${latest.rangesLabel(use24Hour: use24Hour)}'}'
                '${latest.skipped ? ' · skipped alarm' : ''}',
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
                      SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap a night from this week to edit the times.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              for (final night in rows)
                _SleepNightRow(
                  night: night,
                  use24Hour: use24Hour,
                  onTap: onEditNight == null
                      ? null
                      : () => onEditNight!(night),
                ),
            ],
            if (onAddNight != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddNight,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log a night'),
                ),
              ),
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

class _SleepNightRow extends StatelessWidget {
  const _SleepNightRow({
    required this.night,
    required this.use24Hour,
    this.onTap,
  });

  final SleepNight night;
  final bool use24Hour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final range = night.rangesLabel(use24Hour: use24Hour);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      night.shortLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (range.isNotEmpty)
                      Text(
                        range,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                  ],
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
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
