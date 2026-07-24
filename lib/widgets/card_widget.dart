import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../theme/uno_theme.dart';

/// Bir uWin kart yüzünü (veya arka yüzünü) kod ile çizer — bir görsel
/// dosyasına bağımlı değildir. Kart oyunlarının ortak/işlevsel dilini
/// (renkli zemin, köşe endeksleri, ortada büyük sembol) kullanır ama
/// telif nedeniyle bilinen UNO kartlarının kendine özgü ögelerinden
/// kasıtlı olarak farklıdır:
///  - Ortada eğik oval yerine altıgen (hexagon) panel,
///  - Kalın beyaz çerçeve yerine kartın kendi renginin koyu tonunda
///    ince bir kenarlık,
///  - Renk başına UNO'nun ok/dalga/yaprak/yıldız desenleri yerine kendi
///    soyut dokusu (çizgi/nokta/üçgen/baklava),
///  - Joker'de dairesel renk çarkı yerine 4 yapraklı "pervane" rozeti,
///  - Skip/Reverse için UNO'nun kavisli ok ikonları yerine sade Unicode
///    piktogramlar (⊘ / ⇄),
///  - Arka yüzde UNO'nun kırmızı-oval logosu yerine dokulu zemin üstünde
///    "uWin" yazı markası.
class CardWidget extends StatelessWidget {
  final UnoCard? card;

  /// true ise kartın arka yüzü gösterilir (rakibin elindeki kartlar için).
  final bool faceDown;

  /// Oynanabilir kartları vurgulamak için dış parıltı.
  final bool highlighted;

  final VoidCallback? onTap;
  final double width;

  /// Joker kartlar oynandıktan sonra (masadaki açık kart) hangi renk
  /// seçildiyse o renkte çerçeve gösterilir. Elde duran (henüz oynanmamış)
  /// jokerlerde null bırakılır.
  final CardColor? chosenColorOverride;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 62,
    this.chosenColorOverride,
  });

  bool get _isFaceDown => faceDown || card == null;

  Color get _bgColor {
    if (_isFaceDown) return UnoColors.background;
    final c = card!;
    if (c.isWild) return UnoColors.wildCard;
    return UnoColors.forCard(c.color);
  }

  Color get _borderColor {
    if (_isFaceDown) return const Color(0xFF3A4656);
    return Color.lerp(_bgColor, Colors.black, 0.35)!;
  }

  List<BoxShadow> _cardShadows(double width) {
    if (highlighted) {
      return [
        BoxShadow(
          color: const Color(0xDDFFFFFF),
          spreadRadius: width * 0.06,
          blurRadius: 0,
        ),
        const BoxShadow(color: Color(0x70000000), blurRadius: 6, offset: Offset(0, 2)),
      ];
    }
    return const [
      BoxShadow(color: Color(0x60000000), blurRadius: 5, offset: Offset(0, 2)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    // En eski (elle çizilen) kartlarla birebir aynı ebat: height = width x
    // 1,5 ve köşe yuvarlaklığı width x 0,14.
    final radius = BorderRadius.circular(width * 0.14);

    final overrideColor = (!_isFaceDown && card!.isWild && chosenColorOverride != null)
        ? UnoColors.forCard(chosenColorOverride!)
        : null;

    final body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: radius,
        border: Border.all(color: _borderColor, width: math.max(1.5, width * 0.03)),
        boxShadow: _cardShadows(width),
      ),
      foregroundDecoration: overrideColor == null
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: overrideColor, width: width * 0.08),
            ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack(width, height) : _buildFace(width, height),
    );

    return GestureDetector(
      onTap: onTap,
      child: body,
    );
  }

  Widget _buildBack(double w, double h) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _BackStripesPainter()),
        Transform.rotate(
          angle: -math.pi / 9,
          child: Container(
            width: w * 1.4,
            height: h * 0.16,
            color: UnoColors.red.withOpacity(0.9),
          ),
        ),
        Text(
          'uWin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: w * 0.30,
            letterSpacing: -0.5,
            height: 1,
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.35), offset: Offset(0, w * 0.012), blurRadius: w * 0.02),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFace(double w, double h) {
    final c = card!;
    final cornerLabel = c.type == CardType.number ? '${c.value}' : c.label;
    return Stack(
      children: [
        if (!c.isWild)
          Positioned.fill(
            child: CustomPaint(painter: _CardPatternPainter(c.color)),
          ),
        Positioned(
          top: h * 0.06,
          left: w * 0.12,
          child: _cornerIndex(cornerLabel, c.type == CardType.number, w),
        ),
        Positioned(
          bottom: h * 0.06,
          right: w * 0.12,
          child: Transform.rotate(
            angle: math.pi,
            child: _cornerIndex(cornerLabel, c.type == CardType.number, w),
          ),
        ),
        Center(child: c.isWild ? _wildBadge(c, w) : _colorSymbol(c, w)),
      ],
    );
  }

  Widget _cornerIndex(String label, bool isNumber, double w) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: w * (isNumber ? 0.24 : 0.15),
        height: 1,
        shadows: [Shadow(color: Colors.black.withOpacity(0.25), offset: const Offset(0, 1), blurRadius: 2)],
      ),
    );
  }

  /// Sayı/skip/reverse/+2 kartları: eğik oval yerine altıgen panel.
  Widget _colorSymbol(UnoCard c, double w) {
    final panel = w * 0.62;
    final fg = UnoColors.forCard(c.color);
    final label = c.type == CardType.number ? '${c.value}' : c.label;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: panel,
          height: panel,
          child: CustomPaint(painter: _HexagonPainter(Colors.white)),
        ),
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: w * (c.type == CardType.number ? 0.48 : 0.27),
            height: 1,
            shadows: [
              Shadow(color: fg.withOpacity(0.35), offset: Offset(0, w * 0.014), blurRadius: w * 0.02),
            ],
          ),
        ),
      ],
    );
  }

  /// Joker / +4: dairesel renk çarkı yerine 4 yapraklı "pervane" rozeti.
  Widget _wildBadge(UnoCard c, double w) {
    final petal = w * 0.27;
    final radius = w * 0.16;

    Widget petalAt(Color color, Offset dir) {
      return Transform.translate(
        offset: dir * radius,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: petal,
            height: petal,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(petal * 0.24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: petal * 0.1)],
            ),
          ),
        ),
      );
    }

    final flower = SizedBox(
      width: w * 0.66,
      height: w * 0.66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          petalAt(UnoColors.red, const Offset(0, -1)),
          petalAt(UnoColors.blue, const Offset(1, 0)),
          petalAt(UnoColors.yellow, const Offset(0, 1)),
          petalAt(UnoColors.green, const Offset(-1, 0)),
          Container(
            width: w * 0.14,
            height: w * 0.14,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );

    if (c.type == CardType.wild) return flower;

    return Stack(
      alignment: Alignment.center,
      children: [
        flower,
        Positioned(
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: w * 0.07, vertical: w * 0.025),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(w * 0.08),
              border: Border.all(color: Colors.white, width: w * 0.012),
            ),
            child: Text(
              '+4',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: w * 0.20,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Kartın merkezindeki sembol paneli: UNO'nun eğik ovali yerine düz
/// (pointy-top) altıgen.
class _HexagonPainter extends CustomPainter {
  final Color color;
  const _HexagonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 3);
      final p = Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawShadow(path, Colors.black.withOpacity(0.4), 1.2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HexagonPainter oldDelegate) => oldDelegate.color != color;
}

/// Renk başına, UNO'nun ok/dalga/yaprak/yıldız desenleri yerine kendi
/// soyut arka plan dokusu — çok düşük opaklıkla, sayının okunurluğunu
/// bozmadan kart yüzeyine derinlik katar.
class _CardPatternPainter extends CustomPainter {
  final CardColor color;
  const _CardPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    switch (color) {
      case CardColor.red:
        _stripes(canvas, size, paint);
        break;
      case CardColor.blue:
        _dots(canvas, size, paint);
        break;
      case CardColor.green:
        _triangles(canvas, size, paint);
        break;
      case CardColor.yellow:
        _diamonds(canvas, size, paint);
        break;
      case CardColor.wild:
        break;
    }
  }

  void _stripes(Canvas canvas, Size size, Paint fill) {
    final paint = Paint()
      ..color = fill.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    final step = size.width * 0.24;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  void _dots(Canvas canvas, Size size, Paint paint) {
    final r = size.width * 0.032;
    final stepX = size.width * 0.24;
    final stepY = size.height * 0.15;
    var row = 0;
    for (double y = stepY / 2; y < size.height; y += stepY) {
      final offsetX = row.isEven ? 0.0 : stepX / 2;
      for (double x = stepX / 2 + offsetX; x < size.width; x += stepX) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
      row++;
    }
  }

  void _triangles(Canvas canvas, Size size, Paint paint) {
    final s = size.width * 0.09;
    final stepX = size.width * 0.26;
    final stepY = size.height * 0.16;
    var row = 0;
    for (double y = stepY / 2; y < size.height; y += stepY) {
      final offsetX = row.isEven ? 0.0 : stepX / 2;
      for (double x = stepX / 2 + offsetX; x < size.width; x += stepX) {
        final path = Path()
          ..moveTo(x, y - s)
          ..lineTo(x - s, y + s * 0.7)
          ..lineTo(x + s, y + s * 0.7)
          ..close();
        canvas.drawPath(path, paint);
      }
      row++;
    }
  }

  void _diamonds(Canvas canvas, Size size, Paint paint) {
    final s = size.width * 0.07;
    final stepX = size.width * 0.24;
    final stepY = size.height * 0.15;
    var row = 0;
    for (double y = stepY / 2; y < size.height; y += stepY) {
      final offsetX = row.isEven ? 0.0 : stepX / 2;
      for (double x = stepX / 2 + offsetX; x < size.width; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(math.pi / 4);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), paint);
        canvas.restore();
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _CardPatternPainter oldDelegate) => oldDelegate.color != color;
}

/// Kart arka yüzü için ince, tekrarlayan çapraz çizgi dokusu — klasik
/// oyun kartı arka yüzlerindeki "dokuma" hissini verir.
class _BackStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;
    final step = size.width * 0.16;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackStripesPainter oldDelegate) => false;
}
