import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `docs/pisti/index.html` `.back-pattern` — iki katmanlı tekrarlayan gradyan.
class PistiBackPatternPainter extends CustomPainter {
  final double tile;

  const PistiBackPatternPainter({required this.tile});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _drawRepeatingGradient(
      canvas,
      size,
      angleDeg: 45,
      stops: const [
        _Stop(0, Color(0xFF0D47A1)),
        _Stop(6 / 12, Color(0xFF0D47A1)),
        _Stop(6 / 12, Color(0xFF1976D2)),
        _Stop(1, Color(0xFF1976D2)),
      ],
      period: tile,
    );

    _drawRepeatingGradient(
      canvas,
      size,
      angleDeg: -45,
      stops: const [
        _Stop(0, Color(0x00000000)),
        _Stop(5 / 6, Color(0x00000000)),
        _Stop(5 / 6, Color(0x55C62828)),
        _Stop(1, Color(0x55C62828)),
      ],
      period: tile,
    );

    canvas.restore();
  }

  void _drawRepeatingGradient(
    Canvas canvas,
    Size size, {
    required double angleDeg,
    required List<_Stop> stops,
    required double period,
  }) {
    final angle = angleDeg * math.pi / 180;
    final diag = size.width + size.height;
    final paint = Paint();
    final origin = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    canvas.translate(-origin.dx, -origin.dy);

    for (double y = -diag; y < diag; y += period) {
      for (double x = -diag; x < diag; x += period) {
        final rect = Rect.fromLTWH(x, y, period, period);
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [for (final s in stops) s.t],
          colors: [for (final s in stops) s.color],
        ).createShader(rect);
        canvas.drawRect(rect, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PistiBackPatternPainter oldDelegate) =>
      oldDelegate.tile != tile;
}

class _Stop {
  final double t;
  final Color color;
  const _Stop(this.t, this.color);
}
