import 'package:flutter/services.dart';

import '../models/clock_settings.dart';

class WatchWidgetSync {
  WatchWidgetSync._();

  static const _channel = MethodChannel('orlux/widget');

  static Future<void> sync({
    required ClockSettings settings,
    String? timerName,
    String timerMode = 'none',
    int timerAnchorMs = 0,
    String? alarmLine,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'timezone': settings.timezone,
        'face': settings.effectiveDisplayMode.name,
        'use24Hour': settings.use24Hour,
        'showUtc': settings.showUtc,
        'timerName': timerName ?? '',
        'timerMode': timerMode,
        'timerAnchorMs': timerAnchorMs,
        'alarmLine': alarmLine ?? '',
        'widgetSeconds': settings.widgetSeconds,
      });
    } catch (_) {}
  }
}
