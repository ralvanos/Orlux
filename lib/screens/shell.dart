import 'dart:async';

import 'package:flutter/material.dart';

import '../services/clock_storage.dart';
import '../theme.dart';
import 'alarms_screen.dart';
import 'settings_screen.dart';
import 'timers_screen.dart';
import 'watch_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.onPinSettingsChanged});

  final VoidCallback? onPinSettingsChanged;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _watch = GlobalKey<WatchScreenState>();
  final _timers = GlobalKey<TimersScreenState>();
  final _alarms = GlobalKey<AlarmsScreenState>();
  Timer? _alarmTicker;

  @override
  void initState() {
    super.initState();
    _alarmTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      ClockStorage.settleDueAlarms();
    });
  }

  @override
  void dispose() {
    _alarmTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrluxColors.ink,
      body: IndexedStack(
        index: _index,
        children: [
          WatchScreen(key: _watch),
          TimersScreen(key: _timers),
          AlarmsScreen(key: _alarms),
          SettingsScreen(onPinSettingsChanged: widget.onPinSettingsChanged),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          if (i == 0) _watch.currentState?.reload();
          if (i == 1) _timers.currentState?.reload();
          if (i == 2) _alarms.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.watch_later_outlined),
            selectedIcon: Icon(Icons.watch_later),
            label: 'Watch',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timers',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.tune),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
