import 'package:flutter/foundation.dart';

class TimerRing {
  TimerRing._();
  static final TimerRing instance = TimerRing._();

  final ValueNotifier<String?> ringing = ValueNotifier<String?>(null);

  bool get isRinging => ringing.value != null;

  void show(String name) {
    ringing.value = name;
  }

  void clear() {
    ringing.value = null;
  }
}
