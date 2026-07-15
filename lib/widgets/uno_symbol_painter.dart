import 'dart:math' as math;

import 'package:flutter/material.dart';

/// `docs/uno/game.js`'teki svgSkip/svgReverse/svgTwoCards/svgWild/svgFourCards
/// fonksiyonlarının Flutter karşılığı. 100x100 birim bir tuval üzerinde çizip
/// istenen boyuta ölçekler.
enum UnoSymbol { skip, reverse, twoCards, wild, fourCards }

class UnoSymbolPainter extends CustomPainter {
  final UnoSymbol symbol;
  final Color color;

  const UnoSymbolPainter({required this.symbol, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, scale);
    switch (symbol) {
      case UnoSymbol.skip:
        _paintSkip(canvas);
        break;
      case UnoSymbol.reverse:
        _paintReverse(canvas);
        break;
      case UnoSymbol.twoCards:
        _paintTwoCards(canvas);
        break;
      case UnoSymbol.wild:
        _paintWild(canvas);
        break;
      case UnoSymbol.fourCards:
        _paintFourCards(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintSkip(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13;
    canvas.drawCircle(const Offset(50, 50), 33, paint);
    canvas.drawLine(const Offset(27, 73), const Offset(73, 27), paint);
  }

  void _paintReverse(Canvas canvas) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(50, 50);
    canvas.rotate(35 * math.pi / 180);
    canvas.translate(-50, -50);

    final p1 = Path()
      ..moveTo(38, 26)
      ..lineTo(38, 72)
      ..moveTo(38, 26)
      ..lineTo(28, 39)
      ..moveTo(38, 26)
      ..lineTo(48, 39);
    canvas.drawPath(p1, paint);

    final p2 = Path()
      ..moveTo(62, 74)
      ..lineTo(62, 28)
      ..moveTo(62, 74)
      ..lineTo(52, 61)
      ..moveTo(62, 74)
      ..lineTo(72, 61);
    canvas.drawPath(p2, paint);
    canvas.restore();
  }

  void _paintTwoCards(Canvas canvas) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    _rotatedRoundRect(canvas, 20, 24, 40, 56, 7, -16, 40, 52, fill, stroke);
    _rotatedRoundRect(canvas, 40, 20, 40, 56, 7, -16, 60, 48, fill, stroke);
  }

  void _paintFourCards(Canvas canvas) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round;

    _rotatedRoundRect(canvas, 26, 26, 30, 46, 5, -26, 50, 52,
        Paint()..color = const Color(0xFF1976D2), stroke);
    _rotatedRoundRect(canvas, 33, 24, 30, 46, 5, -9, 50, 52,
        Paint()..color = const Color(0xFFD32F2F), stroke);
    _rotatedRoundRect(canvas, 39, 24, 30, 46, 5, 9, 50, 52,
        Paint()..color = const Color(0xFF388E3C), stroke);
    _rotatedRoundRect(canvas, 46, 26, 30, 46, 5, 26, 50, 52,
        Paint()..color = const Color(0xFFF9A825), stroke);
  }

  void _paintWild(Canvas canvas) {
    const colors = [
      Color(0xFFD32F2F),
      Color(0xFFF9A825),
      Color(0xFF388E3C),
      Color(0xFF1976D2),
    ];
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // `docs/uno/game.js` svgWild() yollarıyla birebir aynı dilimler.
    final wedges = [
      _wildWedge(50, 15, 85, 50),
      _wildWedge(85, 50, 50, 85),
      _wildWedge(50, 85, 15, 50),
      _wildWedge(15, 50, 50, 15),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawPath(wedges[i], Paint()..color = colors[i]);
      canvas.drawPath(wedges[i], stroke);
    }
  }

  Path _wildWedge(double x1, double y1, double x2, double y2) {
    return Path()
      ..moveTo(50, 50)
      ..lineTo(x1, y1)
      ..arcToPoint(
        Offset(x2, y2),
        radius: const Radius.circular(35),
        clockwise: true,
      )
      ..close();
  }

  /// (x,y,w,h,radius) tanımlı bir yuvarlak köşeli dikdörtgeni, (cx,cy) etrafında
  /// [degrees] derece döndürerek çizer.
  void _rotatedRoundRect(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    double radius,
    double degrees,
    double cx,
    double cy,
    Paint fill,
    Paint stroke,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-cx, -cy);
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(rrect, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant UnoSymbolPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
