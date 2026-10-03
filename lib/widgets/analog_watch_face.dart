import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class AnalogWatchFace extends StatelessWidget {
  const AnalogWatchFace({
    super.key,
    required this.local,
    required this.utc,
    this.size = 280,
    this.showUtcHand = true,
    this.dim = false,
  });

  final DateTime local;
  final DateTime utc;
  final double size;
  final bool showUtcHand;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WatchPainter(
          local: local,
          utc: utc,
          showUtcHand: showUtcHand,
          dim: dim,
        ),
      ),
    );
  }
}

class _WatchPainter extends CustomPainter {
  _WatchPainter({
    required this.local,
    required this.utc,
    required this.showUtcHand,
    required this.dim,
  });

  final DateTime local;
  final DateTime utc;
  final bool showUtcHand;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 10;

    final ember = const Color(0xFFB85C3A);
    final dial = Paint()
      ..shader = RadialGradient(
        colors: dim
            ? const [
                Color(0xFF1C100C),
                Color(0xFF100A08),
                Color(0xFF070403),
              ]
            : const [
                Color(0xFF243044),
                OrluxColors.surface,
                Color(0xFF0B1018),
              ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, dial);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = (dim
                ? ember
                : (showUtcHand ? OrluxColors.aurora : OrluxColors.ice))
            .withValues(alpha: dim ? 0.4 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    final tick = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < 60; i++) {
      final angle = -math.pi / 2 + (i / 60) * math.pi * 2;
      final major = i % 5 == 0;
      tick.color = major
          ? (dim ? ember.withValues(alpha: 0.42) : Colors.white.withValues(alpha: 0.45))
          : (dim ? ember.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.12));
      tick.strokeWidth = major ? 2.4 : 1.2;
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - (major ? 18 : 10)),
        center.dy + math.sin(angle) * (radius - (major ? 18 : 10)),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 4),
        center.dy + math.sin(angle) * (radius - 4),
      );
      canvas.drawLine(inner, outer, tick);
    }

    if (radius >= 70) {
      const labels = {0: '12', 3: '3', 6: '6', 9: '9'};
      labels.forEach((hour, text) {
        final angle = -math.pi / 2 + hour / 12 * math.pi * 2;
        final offset = Offset(
          center.dx + math.cos(angle) * (radius * 0.72),
          center.dy + math.sin(angle) * (radius * 0.72),
        );
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: (dim ? ember : Colors.white).withValues(alpha: 0.55),
              fontSize: radius * 0.11,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          offset - Offset(painter.width / 2, painter.height / 2),
        );
      });
    }

    void hand({
      required double angle,
      required double length,
      required Color color,
      required double width,
    }) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round;
      final tip = Offset(
        center.dx + math.cos(angle) * length,
        center.dy + math.sin(angle) * length,
      );
      canvas.drawLine(center, tip, paint);
    }

    final localSec = local.second + local.millisecond / 1000;
    final localMin = local.minute + localSec / 60;
    final localHour = (local.hour % 12) + localMin / 60;
    hand(
      angle: -math.pi / 2 + localHour / 12 * math.pi * 2,
      length: radius * 0.5,
      color: dim ? ember : OrluxColors.ice,
      width: 5,
    );
    hand(
      angle: -math.pi / 2 + localMin / 60 * math.pi * 2,
      length: radius * 0.68,
      color: dim ? const Color(0xFFC9A089) : OrluxColors.onInk,
      width: 3.2,
    );
    hand(
      angle: -math.pi / 2 + localSec / 60 * math.pi * 2,
      length: radius * 0.74,
      color: dim ? const Color(0xFF8A4A38) : OrluxColors.mint,
      width: 1.4,
    );

    if (showUtcHand) {
      final utcHour = (utc.hour % 12) + utc.minute / 60;
      hand(
        angle: -math.pi / 2 + utcHour / 12 * math.pi * 2,
        length: radius * 0.38,
        color: dim ? const Color(0xFF8A5A28) : OrluxColors.aurora,
        width: 3,
      );
    }

    canvas.drawCircle(
      center,
      5,
      Paint()
        ..color = dim
            ? ember
            : (showUtcHand ? OrluxColors.aurora : OrluxColors.ice),
    );
  }

  @override
  bool shouldRepaint(covariant _WatchPainter oldDelegate) {
    return oldDelegate.local != local ||
        oldDelegate.utc != utc ||
        oldDelegate.showUtcHand != showUtcHand ||
        oldDelegate.dim != dim;
  }
}
