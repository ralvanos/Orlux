import 'package:flutter/foundation.dart';

import '../models/clock_alarm.dart';

class AlarmRing {
  AlarmRing._();
  static final AlarmRing instance = AlarmRing._();

  final ValueNotifier<ClockAlarm?> ringing = ValueNotifier<ClockAlarm?>(null);

  bool get isRinging => ringing.value != null;

  void show(ClockAlarm alarm) {
    ringing.value = alarm;
  }

  void clear() {
    ringing.value = null;
  }
}
