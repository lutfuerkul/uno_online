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
///  - Kalın beyaz UNO çerçevesi yerine ince açık gri kenarlık,
///  - Bütün renkler aynı soyut çapraz çizgi dokusunu paylaşır,
///  - Skip kartında büyütülmüş ⊘ sembolü + üstte "BLOK" yazısı,
///  - Reverse'te UNO'nun kavisli çift ok ikonu yerine tek düz ok +
///    üstte "TEKRAR" yazısı,
///  - Joker'de dairesel renk çarkı yerine 4 yapraklı "pervane" rozeti +
///    üstünde "RENK SEÇ" yazısı; +4'te aynı rozet, yalnızca köşelerde
///    büyük "+4",
///  - Arka yüzde UNO'nun kırmızı-oval logosu yerine dokulu koyu zemin
///    üstünde "uWin" yazı markası.
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

  /// Kart yüzlerinin hepsi (jokerler dâhil) aynı ince açık gri kenarlığı
  /// paylaşır; yalnızca arka yüz kendi koyu tonunu kullanır.
  Color get _borderColor {
    if (_isFaceDown) return const Color(0xFF3A4656);
    return const Color(0xFFF2F2F2);
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
        border: Border.all(color: _borderColor, width: math.max(1.5, width * 0.054)),
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
      children: [
        // Positioned.fill: yalnızca doku deseni tam kartı kaplasın; "uWin"
        // yazısı ise (Stack'in varsayılan gevşek kısıtı + alignment:center
        // sayesinde) hem yatayda hem dikeyde tam ortada kalsın. Önceden
        // Stack'in fit: StackFit.expand olması Text'i de kartın tam
        // boyutuna zorluyordu; Text kendi kutusunda dikeyde ortalanmadığı
        // için yazı en tepede görünüyordu.
        Positioned.fill(child: CustomPaint(painter: _StripesPainter(Colors.white, 0.05))),
        Text(
          'uWin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: w * 0.34,
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

    if (c.isWild) {
      return Stack(
        children: [
          Center(child: _wildBadge(c, w)),
          if (c.type == CardType.wildDrawFour) ...[
            Positioned(
              top: h * 0.06,
              left: w * 0.12,
              child: _cornerText('+4', w * 0.23),
            ),
            Positioned(
              bottom: h * 0.06,
              right: w * 0.12,
              child: Transform.rotate(angle: math.pi, child: _cornerText('+4', w * 0.23)),
            ),
          ],
        ],
      );
    }

    final cornerLabel = c.type == CardType.number ? '${c.value}' : c.label;
    final title = c.type == CardType.skip
        ? 'BLOK'
        : c.type == CardType.reverse
            ? 'TEKRAR'
            : null;

    final cornerFontSize = w * (c.type == CardType.number ? 0.24 : 0.15);
    final corner = c.type == CardType.reverse
        ? _cornerArrow(w * 0.138)
        : _cornerText(cornerLabel, cornerFontSize);

    return Stack(
      children: [
        Positioned(
          top: h * 0.06,
          left: w * 0.12,
          child: corner,
        ),
        Positioned(
          bottom: h * 0.06,
          right: w * 0.12,
          child: Transform.rotate(
            angle: math.pi,
            child: corner,
          ),
        ),
        if (title != null)
          Positioned(
            top: h * 0.17,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: w * 0.115,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 1), blurRadius: 2)],
                ),
              ),
            ),
          ),
        Center(child: _colorSymbol(c, w)),
      ],
    );
  }

  Widget _cornerText(String label, double fontSize) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
        height: 1,
        shadows: [Shadow(color: Colors.black.withOpacity(0.25), offset: const Offset(0, 1), blurRadius: 2)],
      ),
    );
  }

  Widget _cornerArrow(double size) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ArrowPainter(Colors.white)),
    );
  }

  /// Sayı/skip/reverse/+2 kartları: eğik oval yerine altıgen panel.
  Widget _colorSymbol(UnoCard c, double w) {
    final panel = w * 0.62;
    final fg = UnoColors.forCard(c.color);

    Widget symbol;
    switch (c.type) {
      case CardType.number:
        symbol = _shadowText('${c.value}', fg, w * 0.48);
        break;
      case CardType.skip:
        // Skip amblemi, "BLOK" başlığıyla dengeli dursun diye belirgin
        // şekilde büyütüldü.
        symbol = _shadowText(c.label, fg, w * 0.46);
        break;
      case CardType.reverse:
        symbol = SizedBox(
          width: w * 0.43,
          height: w * 0.43,
          child: CustomPaint(painter: _ArrowPainter(fg)),
        );
        break;
      default:
        symbol = _shadowText(c.label, fg, w * 0.27);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: panel,
          height: panel,
          child: CustomPaint(painter: _HexagonPainter(Colors.white)),
        ),
        symbol,
      ],
    );
  }

  Widget _shadowText(String label, Color color, double fontSize) {
    return Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        height: 1,
        shadows: [
          Shadow(color: color.withOpacity(0.35), offset: Offset(0, fontSize * 0.03), blurRadius: fontSize * 0.04),
        ],
      ),
    );
  }

  /// Joker / +4: dairesel renk çarkı yerine 4 yapraklı "pervane" rozeti.
  /// Joker'de üstünde "RENK SEÇ" yazısı da bulunur; +4'te bu rozet
  /// tek başına durur (metin köşelerdeki büyük "+4" ile veriliyor).
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

    if (c.type != CardType.wild) return flower;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RENK SEÇ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: w * 0.115,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Colors.black.withOpacity(0.3), offset: const Offset(0, 1), blurRadius: 2)],
          ),
        ),
        SizedBox(height: w * 0.06),
        flower,
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

/// Reverse: UNO'nun iki-ok ikonu yerine tek parça (şaft + ok ucu birleşik
/// bir Path), diyagonal, düz ok.
class _ArrowPainter extends CustomPainter {
  final Color color;
  const _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final path = Path()
      ..moveTo(8 * s, 40 * s)
      ..lineTo(54 * s, 40 * s)
      ..lineTo(54 * s, 22 * s)
      ..lineTo(96 * s, 50 * s)
      ..lineTo(54 * s, 78 * s)
      ..lineTo(54 * s, 60 * s)
      ..lineTo(8 * s, 60 * s)
      ..close();
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawShadow(path, Colors.black.withOpacity(0.35), 1.0, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => oldDelegate.color != color;
}

/// Bütün renklerin paylaştığı ortak arka plan dokusu: ince, tekrarlayan
/// çapraz çizgiler — çok düşük opaklıkla, sayının okunurluğunu bozmadan
/// kart yüzeyine derinlik katar.
class _StripesPainter extends CustomPainter {
  final Color color;
  final double opacity;
  const _StripesPainter(this.color, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05;
    final step = size.width * 0.24;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
