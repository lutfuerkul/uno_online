import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pisti_card.dart';

/// `docs/pisti/game.js`'teki `courtArt()` SVG'sinin Flutter karşılığı: Vale
/// (yeşil), Kız (mavi), Papaz (kırmızı) için taç + yüz + cübbe deseni,
/// kartın üstünde ve altında simetrik (180° döndürülmüş) olacak şekilde iki
/// kez çizilir. Orijinal SVG 100x150 birimlik bir tuval varsayar.
class PistiCourtPainter extends CustomPainter {
  final PistiRank rank;

  const PistiCourtPainter({required this.rank});

  Color get _gemColor {
    switch (rank) {
      case PistiRank.king:
        return const Color(0xFFC62828);
      case PistiRank.queen:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Web SVG: preserveAspectRatio="xMidYMid meet"
    final scale = math.min(size.width / 100, size.height / 150);
    final dx = (size.width - 100 * scale) / 2;
    final dy = (size.height - 150 * scale) / 2;
    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    // Kartın altındaki krem zeminli, altın çerçeveli panel.
    final bgPaint = Paint()..color = const Color(0xFFFFFDF5);
    final bgStroke = Paint()
      ..color = const Color(0xFFC9A227)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final bgRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, 90, 140),
      const Radius.circular(7),
    );
    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, bgStroke);

    _drawDashedLine(canvas, const Offset(12, 75), const Offset(88, 75),
        const Color(0xFFC9A227), 1);

    _drawHalf(canvas);
    canvas.save();
    canvas.translate(50, 75);
    canvas.rotate(3.14159265359);
    canvas.translate(-50, -75);
    _drawHalf(canvas);
    canvas.restore();

    canvas.restore();
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    const dashLen = 3.0;
    const gapLen = 2.5;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var dist = 0.0;
    while (dist < total) {
      final start = a + dir * dist;
      final end = a + dir * (dist + dashLen).clamp(0, total);
      canvas.drawLine(start, end, paint);
      dist += dashLen + gapLen;
    }
  }

  void _drawHalf(Canvas canvas) {
    final groupStroke = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Taç.
    final crown = Path()
      ..moveTo(34, 33)
      ..lineTo(38, 22)
      ..lineTo(44, 30)
      ..lineTo(50, 20)
      ..lineTo(56, 30)
      ..lineTo(62, 22)
      ..lineTo(66, 33)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFF4C430));
    canvas.drawPath(crown, groupStroke);

    for (final gem in [const Offset(38, 22), const Offset(50, 20), const Offset(62, 22)]) {
      canvas.drawCircle(gem, 1.8, Paint()..color = _gemColor);
      canvas.drawCircle(gem, 1.8, groupStroke);
    }

    final band = Rect.fromLTWH(34, 33, 32, 5);
    canvas.drawRect(band, Paint()..color = const Color(0xFFC62828));
    canvas.drawRect(band, groupStroke);

    final face = Rect.fromCenter(center: const Offset(50, 46), width: 17, height: 19);
    canvas.drawOval(face, Paint()..color = const Color(0xFFF6D7B8));
    canvas.drawOval(face, groupStroke);

    final eyeStroke = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(41.5, 44), const Offset(45.5, 44), eyeStroke);
    canvas.drawLine(const Offset(54.5, 44), const Offset(58.5, 44), eyeStroke);

    final mouth = Path()..moveTo(47, 50)..quadraticBezierTo(50, 52, 53, 50);
    canvas.drawPath(mouth, eyeStroke);

    final robe = Path()
      ..moveTo(33, 74)
      ..quadraticBezierTo(33, 55, 50, 55)
      ..quadraticBezierTo(67, 55, 67, 74)
      ..close();
    canvas.drawPath(robe, Paint()..color = const Color(0xFFC62828));
    canvas.drawPath(robe, groupStroke);

    final collar = Path()
      ..moveTo(45, 55)
      ..lineTo(50, 63)
      ..lineTo(55, 55)
      ..close();
    canvas.drawPath(collar, Paint()..color = const Color(0xFFF4C430));
    canvas.drawPath(collar, groupStroke);

    canvas.drawLine(
      const Offset(50, 63),
      const Offset(50, 74),
      Paint()
        ..color = const Color(0xFFF4C430)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant PistiCourtPainter oldDelegate) => oldDelegate.rank != rank;
}
