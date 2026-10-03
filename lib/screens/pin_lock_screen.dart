import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/export_crypto.dart';
import '../services/pin_service.dart';
import '../theme.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    this.title = 'Enter PIN',
  });

  final VoidCallback onUnlocked;
  final String title;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String? _error;
  bool _busy = false;

  Future<void> _submit(String pin) async {
    if (!PinService.isValidPinFormat(pin)) {
      setState(() {
        _error =
            'Enter a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN';
      });
      return;
    }
    final throttle = PinService.instance.throttleRemaining();
    if (throttle != null) {
      setState(() {
        _error = 'Too many attempts. Try again in ${throttle.inSeconds}s';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await PinService.instance.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
      return;
    }
    final remaining = PinService.instance.throttleRemaining();
    setState(() {
      _busy = false;
      _pin = '';
      _error = remaining != null
          ? 'Too many attempts. Try again in ${remaining.inSeconds}s'
          : 'Incorrect PIN';
    });
  }

  void _tap(String digit) {
    if (_busy) return;
    if (_pin.length >= PinService.maxPinLength) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length >= PinService.maxPinLength) _submit(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OrluxColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const Spacer(),
              const Icon(Icons.lock_outline, size: 40, color: OrluxColors.aurora),
              const SizedBox(height: 20),
              Text(
                widget.title,
                style: const TextStyle(
                  color: OrluxColors.onInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlock to use Orlux',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < PinService.maxPinLength; i++)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? OrluxColors.aurora
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: OrluxColors.danger, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              _Pad(
                enabled: !_busy,
                onDigit: _tap,
                onBackspace: () {
                  if (_busy || _pin.isEmpty) return;
                  setState(() => _pin = _pin.substring(0, _pin.length - 1));
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : () => _submit(_pin),
                  style: FilledButton.styleFrom(
                    backgroundColor: OrluxColors.aurora,
                    foregroundColor: const Color(0xFF1A1408),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1A1408),
                          ),
                        )
                      : const Text('Unlock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Column(
      children: [
        for (final row in keys)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final key in row)
                _Key(
                  label: key,
                  enabled: enabled,
                  onTap: () {
                    if (key == 'del') {
                      onBackspace();
                    } else if (key.isNotEmpty) {
                      onDigit(key);
                    }
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox(width: 76, height: 76);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: OrluxColors.card,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 76,
            height: 76,
            child: Center(
              child: label == 'del'
                  ? const Icon(Icons.backspace_outlined, color: OrluxColors.onInk)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: OrluxColors.onInk,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class ExportPromptResult {
  const ExportPromptResult._(this.passphrase);
  const ExportPromptResult.plaintext() : this._(null);
  const ExportPromptResult.protected(String passphrase) : this._(passphrase);
  final String? passphrase;
  bool get pinProtected => passphrase != null;
}

class PinDialogs {
  PinDialogs._();

  static InputDecoration _decoration(BuildContext ctx, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      counterText: '',
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(ctx).colorScheme.primary),
      ),
    );
  }

  static Future<String?> promptNewPin(
    BuildContext context, {
    required String title,
  }) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: OrluxColors.card,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN. '
                  'It is stored as a salted hash — not in plaintext.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(ctx, 'PIN'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(ctx, 'Confirm PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = pinController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (!PinService.isValidPinFormat(pin)) {
                    setDialogState(() {
                      error =
                          'PIN must be ${PinService.minPinLength}–${PinService.maxPinLength} digits';
                    });
                    return;
                  }
                  if (pin != confirm) {
                    setDialogState(() => error = 'PINs do not match');
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: OrluxColors.aurora,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  static Future<String?> promptCurrentPin(
    BuildContext context, {
    required String title,
  }) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: OrluxColors.card,
            title: Text(title, style: const TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: PinService.maxPinLength,
                  style: const TextStyle(color: Colors.white),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _decoration(ctx, 'Current PIN'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (!PinService.isValidPinFormat(pin)) {
                    setDialogState(() {
                      error =
                          'Enter a ${PinService.minPinLength}–${PinService.maxPinLength} digit PIN';
                    });
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: OrluxColors.aurora,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }

  static Future<ExportPromptResult?> promptExport(BuildContext context) async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    var protect = false;
    String? error;
    final result = await showModalBottomSheet<ExportPromptResult>(
      context: context,
      backgroundColor: OrluxColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Export',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saves a JSON backup. PIN-protect it if you will store the file somewhere else.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: protect,
                      activeThumbColor: OrluxColors.aurora,
                      title: const Text('PIN-protect this file'),
                      onChanged: (value) => setSheet(() {
                        protect = value;
                        error = null;
                      }),
                    ),
                    if (protect) ...[
                      TextField(
                        controller: pinController,
                        obscureText: true,
                        maxLength: ExportCrypto.maxPassphraseLength,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(ctx, 'Export PIN / passphrase'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmController,
                        obscureText: true,
                        maxLength: ExportCrypto.maxPassphraseLength,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration(ctx, 'Confirm'),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: OrluxColors.danger)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (!protect) {
                          Navigator.pop(ctx, const ExportPromptResult.plaintext());
                          return;
                        }
                        final pin = pinController.text.trim();
                        final confirm = confirmController.text.trim();
                        if (!ExportCrypto.isValidPassphrase(pin)) {
                          setSheet(() {
                            error =
                                'Use ${ExportCrypto.minPassphraseLength}–${ExportCrypto.maxPassphraseLength} characters';
                          });
                          return;
                        }
                        if (pin != confirm) {
                          setSheet(() => error = 'Entries do not match');
                          return;
                        }
                        Navigator.pop(ctx, ExportPromptResult.protected(pin));
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: OrluxColors.aurora,
                        foregroundColor: const Color(0xFF1A1408),
                      ),
                      child: Text(protect ? 'Encrypt & export' : 'Export'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    pinController.dispose();
    confirmController.dispose();
    return result;
  }

  static Future<String?> promptImportPassphrase(BuildContext context) async {
    final controller = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: OrluxColors.card,
            title: const Text('Enter export PIN',
                style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This backup is PIN-protected. A wrong PIN will not erase your data.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  obscureText: true,
                  autofocus: true,
                  maxLength: ExportCrypto.maxPassphraseLength,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(ctx, 'Export PIN / passphrase'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final pin = controller.text.trim();
                  if (!ExportCrypto.isValidPassphrase(pin)) {
                    setDialogState(() {
                      error =
                          'Enter at least ${ExportCrypto.minPassphraseLength} characters';
                    });
                    return;
                  }
                  Navigator.pop(ctx, pin);
                },
                child: const Text(
                  'Unlock backup',
                  style: TextStyle(
                    color: OrluxColors.aurora,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result;
  }
}
