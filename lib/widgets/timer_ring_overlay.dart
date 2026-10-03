import 'package:flutter/material.dart';

import '../services/clock_storage.dart';
import '../services/timer_ring.dart';
import '../theme.dart';

class TimerRingOverlay extends StatelessWidget {
  const TimerRingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: TimerRing.instance.ringing,
      builder: (context, name, _) {
        if (name == null) return const SizedBox.shrink();
        return Material(
          color: Colors.black.withValues(alpha: 0.78),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 52,
                      color: OrluxColors.aurora,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: OrluxColors.onInk,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Countdown finished',
                      style: TextStyle(
                        fontSize: 16,
                        color: OrluxColors.ice,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: ClockStorage.stopRingingTimer,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Stop'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
