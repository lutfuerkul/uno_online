import 'package:flutter/material.dart';

/// `docs/pisti/index.html`'deki `.back-pattern` CSS desenine (iki yönlü
/// tekrarlayan çapraz çizgiler) yakın bir doku çizer.
class PistiBackPatternPainter extends CustomPainter {
  final double tile;

  const PistiBackPatternPainter({required this.tile});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final bluePaint = Paint()..color = const Color(0xFF1976D2);
    canvas.drawRect(Offset.zero & size, bluePaint);

    final darkStripe = Paint()
      ..color = const Color(0xFF0D47A1)
      ..strokeWidth = tile * 0.5;
    final diag = size.width + size.height;
    for (double d = -diag; d < diag; d += tile) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        darkStripe,
      );
    }

    final redAccent = Paint()
      ..color = const Color(0x55C62828)
      ..strokeWidth = tile * 0.12;
    for (double d = 0; d < diag * 2; d += tile) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d - size.height, size.height),
        redAccent,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PistiBackPatternPainter oldDelegate) =>
      oldDelegate.tile != tile;
}
