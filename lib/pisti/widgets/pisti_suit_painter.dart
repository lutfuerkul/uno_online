import 'package:flutter/material.dart';

import '../models/pisti_card.dart';

/// `docs/pisti/game.js` köşe/orta takım sembolleri (♠♥♦♣) — Unicode font
/// boyutu cihazdan cihaza değiştiği için vektör olarak çizilir.
class PistiSuitPainter extends CustomPainter {
  final PistiSuit suit;
  final Color color;

  const PistiSuitPainter({required this.suit, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);
    switch (suit) {
      case PistiSuit.spades:
        _paintSpade(canvas, paint);
      case PistiSuit.hearts:
        _paintHeart(canvas, paint);
      case PistiSuit.diamonds:
        _paintDiamond(canvas, paint);
      case PistiSuit.clubs:
        _paintClub(canvas, paint);
    }
    canvas.restore();
  }

  void _paintHeart(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(50, 78)
      ..cubicTo(20, 55, 20, 28, 50, 38)
      ..cubicTo(80, 28, 80, 55, 50, 78)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintDiamond(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(50, 18)
      ..lineTo(78, 50)
      ..lineTo(50, 82)
      ..lineTo(22, 50)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintSpade(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(50, 22)
      ..cubicTo(22, 42, 22, 62, 50, 58)
      ..cubicTo(78, 62, 78, 42, 50, 22)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRect(const Rect.fromLTWH(46, 58, 8, 22), paint);
    canvas.drawRect(const Rect.fromLTWH(38, 78, 24, 6), paint);
  }

  void _paintClub(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(50, 34), 14, paint);
    canvas.drawCircle(const Offset(32, 52), 14, paint);
    canvas.drawCircle(const Offset(68, 52), 14, paint);
    canvas.drawRect(const Rect.fromLTWH(46, 52, 8, 28), paint);
    canvas.drawRect(const Rect.fromLTWH(38, 76, 24, 6), paint);
  }

  @override
  bool shouldRepaint(covariant PistiSuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

/// Takım sembolü widget'ı — [size] web'deki `font-size: calc(var(--w) * ratio)`.
class PistiSuitGlyph extends StatelessWidget {
  final PistiSuit suit;
  final double size;
  final Color color;

  const PistiSuitGlyph({
    super.key,
    required this.suit,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: PistiSuitPainter(suit: suit, color: color),
      ),
    );
  }
}
