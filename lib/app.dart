import 'package:flutter/material.dart';

import 'screens/pin_lock_screen.dart';
import 'screens/shell.dart';
import 'services/auto_lock_policy.dart';
import 'services/clock_storage.dart';
import 'services/native_alerts.dart';
import 'services/pin_service.dart';
import 'theme.dart';
import 'widgets/alarm_ring_overlay.dart';
import 'widgets/timer_ring_overlay.dart';

class OrluxApp extends StatefulWidget {
  const OrluxApp({super.key});

  @override
  State<OrluxApp> createState() => _OrluxAppState();
}

class _OrluxAppState extends State<OrluxApp> with WidgetsBindingObserver {
  bool _pinEnabled = false;
  bool _unlocked = true;
  bool _ready = false;
  int _autoLockSeconds = AutoLockPolicy.defaultTimeoutSeconds;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPinState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadPinState({bool preserveSession = false}) async {
    final enabled = await PinService.instance.isEnabled();
    final autoLock = await ClockStorage.getAutoLockTimeoutSeconds();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _autoLockSeconds = autoLock;
      if (!preserveSession) {
        _unlocked = !enabled;
      } else if (!enabled) {
        _unlocked = true;
      }
      _ready = true;
    });
  }

  void refreshPinLock() {
    _loadPinState(preserveSession: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ClockStorage.rescheduleAll();
      ClockStorage.settleDueAlarms();
      NativeAlerts.takePending().then(ClockStorage.handleNativeFire);
    }
    if (!_pinEnabled) return;
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      if (AutoLockPolicy.lockImmediatelyOnPause(_autoLockSeconds) &&
          _unlocked) {
        setState(() => _unlocked = false);
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      if (_unlocked &&
          AutoLockPolicy.shouldLockOnResume(
            timeoutSeconds: _autoLockSeconds,
            pausedAt: _pausedAt,
            now: DateTime.now(),
          )) {
        setState(() => _unlocked = false);
      }
      _pausedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orlux',
      debugShowCheckedModeBanner: false,
      theme: OrluxTheme.dark(),
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const AlarmRingOverlay(),
            const TimerRingOverlay(),
          ],
        );
      },
      home: !_ready
          ? const Scaffold(
              backgroundColor: OrluxColors.ink,
              body: Center(
                child: CircularProgressIndicator(color: OrluxColors.aurora),
              ),
            )
          : (_pinEnabled && !_unlocked)
              ? PinLockScreen(
                  onUnlocked: () => setState(() => _unlocked = true),
                )
              : MainShell(onPinSettingsChanged: refreshPinLock),
    );
  }
}
