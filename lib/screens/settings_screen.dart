import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../models/clock_settings.dart';
import '../models/clock_sound.dart';
import '../services/auto_lock_policy.dart';
import '../services/clock_storage.dart';
import '../services/native_alerts.dart';
import '../services/pin_service.dart';
import '../theme.dart';
import '../widgets/alert_sound_picker.dart';
import '../widgets/orlux_card.dart';
import '../widgets/timezone_picker.dart';
import 'pin_lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onPinSettingsChanged});

  final VoidCallback? onPinSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ClockSettings? _settings;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ClockStorage.getSettings();
    final pin = await PinService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _pinEnabled = pin;
    });
  }

  Future<void> _persist(ClockSettings settings) async {
    await ClockStorage.saveSettings(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await PinDialogs.promptExport(context);
    if (choice == null) return;
    final result = await ClockStorage.exportData(passphrase: choice.passphrase);
    if (!mounted) return;
    final message = switch (result) {
      ExportResult.success =>
        choice.pinProtected ? 'PIN-protected backup saved' : 'Backup saved',
      ExportResult.cancelled => 'Export cancelled',
      ExportResult.failure => 'Export failed',
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    var result = await ClockStorage.pickAndParseImport();
    if (!mounted) return;
    if (result.needsPassphrase) {
      final pin = await PinDialogs.promptImportPassphrase(context);
      if (pin == null) return;
      result = ClockStorage.decryptAndValidateImport(
        encryptedEnvelope: result.encryptedEnvelope!,
        passphrase: pin,
      );
    }
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Import failed')),
      );
      return;
    }
    await ClockStorage.applyImport(result.data!);
    widget.onPinSettingsChanged?.call();
    await _load();
    messenger.showSnackBar(const SnackBar(content: Text('Backup imported')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      return const Center(
        child: CircularProgressIndicator(color: OrluxColors.aurora),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'More',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Timezone, display, tones, lock, and backups. Everything stays on this device.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const _SectionTitle('Watch'),
          OrluxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TimezonePickerTile(
                  value: settings.timezone,
                  onChanged: (zone) =>
                      _persist(settings.copyWith(timezone: zone)),
                ),
                const Divider(height: 20),
                const Text('Time format'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('24-hour'),
                      selected: settings.use24Hour,
                      selectedColor: OrluxColors.aurora,
                      onSelected: (_) =>
                          _persist(settings.copyWith(use24Hour: true)),
                    ),
                    ChoiceChip(
                      label: const Text('12-hour'),
                      selected: !settings.use24Hour,
                      selectedColor: OrluxColors.aurora,
                      onSelected: (_) =>
                          _persist(settings.copyWith(use24Hour: false)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Night dim'),
                const SizedBox(height: 4),
                Text(
                  'Softer ember face. Auto uses 9pm–7am in your timezone.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in NightDimMode.values)
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: settings.nightDimMode == mode,
                        selectedColor: OrluxColors.aurora,
                        onSelected: (_) =>
                            _persist(settings.copyWith(nightDimMode: mode)),
                      ),
                  ],
                ),
                const Divider(height: 20),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.showUtc,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Show UTC'),
                  subtitle: const Text(
                    'Second clock on the watch. Off hides Analog + UTC, Dual analog, and Stacked.',
                  ),
                  onChanged: (v) {
                    final nextMode = v
                        ? settings.displayMode
                        : settings.displayMode.withoutUtc;
                    _persist(
                      settings.copyWith(showUtc: v, displayMode: nextMode),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text('Face'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final mode in DisplayModeLabel.availableFaces(
                      showUtc: settings.showUtc,
                    ))
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: settings.effectiveDisplayMode == mode,
                        selectedColor: OrluxColors.aurora,
                        onSelected: (_) =>
                            _persist(settings.copyWith(displayMode: mode)),
                      ),
                  ],
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.keepAwake,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Keep screen awake'),
                  subtitle: const Text('On the watch face while Orlux is open.'),
                  onChanged: (v) => _persist(settings.copyWith(keepAwake: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.showStatusNotifications,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Status bar notices'),
                  subtitle: const Text(
                    'Quiet ongoing notice for a running timer and the next alarm.',
                  ),
                  onChanged: (v) =>
                      _persist(settings.copyWith(showStatusNotifications: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow background alarms'),
                  subtitle: const Text(
                    'Turn off battery optimization so alarms and timers still ring when Orlux is closed.',
                  ),
                  onTap: () => NativeAlerts.requestBatteryExemption(),
                ),
                const Divider(height: 20),
                const Text('Home screen widgets'),
                const SizedBox(height: 4),
                Text(
                  'Long-press the home screen, choose Widgets, then Orlux 2×2 or Orlux 4×4. Both stay centered and show UTC plus the next timer or alarm.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.widgetSeconds,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Seconds sweep'),
                  subtitle: const Text(
                    'A small seconds hand on the home widget. The launcher ticks it, so Orlux does not wake every second.',
                  ),
                  onChanged: (v) =>
                      _persist(settings.copyWith(widgetSeconds: v)),
                ),
              ],
            ),
          ),
          const _SectionTitle('Sound'),
          OrluxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.haptics,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Haptic feedback'),
                  onChanged: (v) => _persist(settings.copyWith(haptics: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.sound,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Sounds'),
                  subtitle: const Text(
                    'Clicks and the default tone. Each timer and alarm can pick its own.',
                  ),
                  onChanged: (v) => _persist(settings.copyWith(sound: v)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.crescendo,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Crescendo alarms'),
                  subtitle: const Text(
                    'Start quiet and rise over about 20 seconds.',
                  ),
                  onChanged: (v) => _persist(settings.copyWith(crescendo: v)),
                ),
                const SizedBox(height: 4),
                AlertSoundPicker(
                  soundId: settings.alertSoundId,
                  allowDefault: false,
                  showImport: true,
                  allowDelete: true,
                  onChanged: (id) => _persist(
                    settings.copyWith(
                      alertSoundId: id ?? SoundCatalog.defaultId,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const _SectionTitle('Sleep'),
          OrluxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.bedtimeReminder,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Bedtime reminder'),
                  subtitle: const Text(
                    'A quiet notice at each sleep-tracking alarm’s usual bedtime.',
                  ),
                  onChanged: (v) =>
                      _persist(settings.copyWith(bedtimeReminder: v)),
                ),
                const Text('Sleep goal'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final hours in const [6.0, 7.0, 7.5, 8.0, 9.0])
                      ChoiceChip(
                        label: Text('${hours}h'),
                        selected: settings.sleepGoalMinutes == (hours * 60).round(),
                        selectedColor: OrluxColors.aurora,
                        onSelected: (_) => _persist(
                          settings.copyWith(
                            sleepGoalMinutes: (hours * 60).round(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const _SectionTitle('Security'),
          OrluxCard(
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _pinEnabled,
                  activeThumbColor: OrluxColors.aurora,
                  title: const Text('Require PIN'),
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    if (value) {
                      final pin =
                          await PinDialogs.promptNewPin(context, title: 'Set PIN');
                      if (pin == null) return;
                      await PinService.instance.setPin(pin);
                      if (!mounted) return;
                      setState(() => _pinEnabled = true);
                      widget.onPinSettingsChanged?.call();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('PIN lock enabled')),
                      );
                    } else {
                      final current = await PinDialogs.promptCurrentPin(
                        context,
                        title: 'Confirm PIN to turn off',
                      );
                      if (current == null) return;
                      try {
                        await PinService.instance.disablePin(current);
                        if (!mounted) return;
                        setState(() => _pinEnabled = false);
                        widget.onPinSettingsChanged?.call();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('PIN lock disabled')),
                        );
                      } catch (_) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Incorrect PIN')),
                        );
                      }
                    }
                  },
                ),
                if (_pinEnabled)
                  DropdownButtonFormField<int>(
                    key: ValueKey(settings.autoLockTimeoutSeconds),
                    initialValue: settings.autoLockTimeoutSeconds,
                    dropdownColor: OrluxColors.card,
                    decoration: const InputDecoration(labelText: 'Auto-lock'),
                    items: [
                      for (final seconds in AutoLockPolicy.allowedTimeoutSeconds)
                        DropdownMenuItem(
                          value: seconds,
                          child: Text(AutoLockPolicy.labelForTimeout(seconds)),
                        ),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await ClockStorage.setAutoLockTimeoutSeconds(value);
                      widget.onPinSettingsChanged?.call();
                      await _load();
                    },
                  ),
              ],
            ),
          ),
          const _SectionTitle('Backup'),
          OrluxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Import and export JSON on this device. PIN-protect is optional when you export.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _import,
                        child: const Text('Import'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _export,
                        child: const Text('Export'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _SectionTitle('About'),
          OrluxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kSupportTheAppMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: kFeedbackEmail,
                      query: 'subject=Orlux feedback',
                    ),
                  ),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Send feedback'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bitcoin'),
                  subtitle: const Text(kDonateBtcAddress),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: kDonateBtcAddress),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bitcoin address copied')),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Monero'),
                  subtitle: const Text(kDonateXmrAddress),
                  onTap: () {
                    Clipboard.setData(
                      const ClipboardData(text: kDonateXmrAddress),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Monero address copied')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
