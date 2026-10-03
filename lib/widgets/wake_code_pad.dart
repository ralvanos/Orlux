import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

class WakeCodePad extends StatefulWidget {
  const WakeCodePad({
    super.key,
    required this.onSolved,
    this.onCancel,
    this.title = 'Enter the code',
  });

  final VoidCallback onSolved;
  final VoidCallback? onCancel;
  final String title;

  static Future<void> showPractice(BuildContext context) async {
    final solved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: OrluxColors.card,
          title: const Text('Try the wake code'),
          content: SingleChildScrollView(
            child: WakeCodePad(
              title: 'Type this code',
              onSolved: () => Navigator.pop(ctx, true),
              onCancel: () => Navigator.pop(ctx, false),
            ),
          ),
        );
      },
    );
    if (solved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That is the step used to stop the alarm.'),
        ),
      );
    }
  }

  @override
  State<WakeCodePad> createState() => _WakeCodePadState();
}

class _WakeCodePadState extends State<WakeCodePad> {
  late final String _code;
  late final List<int> _keys;
  String _typed = '';

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _code = List.generate(4, (_) => rng.nextInt(10)).join();
    _keys = List<int>.generate(10, (i) => i)..shuffle(rng);
  }

  void _tap(int digit) {
    if (_typed.length >= 4) return;
    final next = '$_typed$digit';
    setState(() => _typed = next);
    if (next.length == 4) {
      if (next == _code) {
        widget.onSolved();
      } else {
        setState(() => _typed = '');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: OrluxColors.onInk,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Keys are shuffled. A wrong code clears.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _code,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
            color: OrluxColors.aurora,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _typed.padRight(4, '·').split('').join(' '),
          style: const TextStyle(
            fontSize: 22,
            letterSpacing: 6,
            color: OrluxColors.ice,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final digit in _keys)
              SizedBox(
                width: 64,
                height: 52,
                child: FilledButton(
                  onPressed: () => _tap(digit),
                  style: FilledButton.styleFrom(
                    backgroundColor: OrluxColors.surface,
                    foregroundColor: OrluxColors.onInk,
                  ),
                  child: Text(
                    '$digit',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.onCancel != null) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Back'),
          ),
        ],
      ],
    );
  }
}
