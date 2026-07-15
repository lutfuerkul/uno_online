import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../theme/uno_theme.dart';
import 'uno_symbol_painter.dart';

/// Bir UNO kartını (veya arka yüzünü) çizer — `docs/uno/game.js`'teki
/// `cardHtml()` ile birebir aynı görsel dili kullanır: köşeleri yuvarlak,
/// beyaz çerçeveli, ortasında eğik oval ve büyük sembol olan klasik UNO
/// kartı.
class CardWidget extends StatelessWidget {
  final UnoCard? card;

  /// true ise kartın arka yüzü gösterilir (rakibin elindeki kartlar için).
  final bool faceDown;

  /// Oynanabilir kartları vurgulamak için dış parıltı.
  final bool highlighted;

  final VoidCallback? onTap;
  final double width;

  /// Joker kartlar oynandıktan sonra (masadaki açık kart) hangi renk
  /// seçildiyse o rengi gösterir. Elde duran (henüz oynanmamış) jokerlerde
  /// null bırakılır.
  final CardColor? chosenColorOverride;

  /// Rakip elindeki üst üste binen kart yığınlarında "UNO" logosu
  /// okunaksız olacağı için gizlenir.
  final bool showBackLogo;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 62,
    this.chosenColorOverride,
    this.showBackLogo = true,
  });

  static Color colorFor(CardColor c) => UnoColors.forCard(c);

  bool get _isFaceDown => faceDown || card == null;

  Color get _backgroundColor {
    if (_isFaceDown) return UnoColors.cardBack;
    final c = card!;
    if (c.isWild) {
      return chosenColorOverride != null
          ? UnoColors.forCard(chosenColorOverride!)
          : UnoColors.wildCard;
    }
    return UnoColors.forCard(c.color);
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
    final border = width * 0.07;

    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: Colors.white, width: border),
        boxShadow: _cardShadows(width),
      ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack() : _buildFront(),
    );

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }

  Widget _buildBack() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: 24 * math.pi / 180,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.98,
            child: ClipOval(child: Container(color: const Color(0xFF111111))),
          ),
        ),
        if (showBackLogo)
          Transform.rotate(
            angle: -20 * math.pi / 180,
            child: _StrokedText(
              'UNO',
              fontSize: width * 0.34,
              fillColor: UnoColors.yellow,
              strokeColor: UnoColors.cardBack,
              strokeWidth: width * 0.022,
              italic: true,
            ),
          ),
      ],
    );
  }

  Widget _buildFront() {
    final c = card!;
    final isWildUnselected = c.isWild && chosenColorOverride == null;

    if (isWildUnselected && c.type == CardType.wild) {
      return Center(
        child: Transform.rotate(
          angle: 24 * math.pi / 180,
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.98,
            child: ClipOval(
              child: CustomPaint(
                painter: const UnoSymbolPainter(symbol: UnoSymbol.wild),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    }

    final effectiveColor = c.isWild ? chosenColorOverride : c.color;
    final hex = effectiveColor != null ? UnoColors.forCard(effectiveColor) : Colors.white;

    return Stack(
      children: [
        Center(
          child: Transform.rotate(
            angle: 24 * math.pi / 180,
            child: FractionallySizedBox(
              widthFactor: 0.8,
              heightFactor: 0.98,
              child: ClipOval(child: Container(color: Colors.white)),
            ),
          ),
        ),
        Center(child: _buildCenterPip(c, isWildUnselected, hex)),
        Positioned(
          top: width * 0.07,
          left: width * 0.09,
          child: _cornerText(_cornerSymbol(c, isWildUnselected)),
        ),
        Positioned(
          bottom: width * 0.07,
          right: width * 0.09,
          child: Transform.rotate(
            angle: math.pi,
            child: _cornerText(_cornerSymbol(c, isWildUnselected)),
          ),
        ),
      ],
    );
  }

  Widget _buildCenterPip(UnoCard c, bool isWildUnselected, Color hex) {
    if (isWildUnselected && c.type == CardType.wildDrawFour) {
      return SizedBox(
        width: width * 0.66,
        height: width * 0.66,
        child: const CustomPaint(painter: UnoSymbolPainter(symbol: UnoSymbol.fourCards)),
      );
    }
    switch (c.type) {
      case CardType.number:
        return _StrokedText(
          '${c.value}',
          fontSize: width * 0.56,
          fillColor: hex,
          strokeColor: const Color(0x40000000),
          strokeWidth: width * 0.014,
        );
      case CardType.skip:
        return SizedBox(
          width: width * 0.66,
          height: width * 0.66,
          child: CustomPaint(painter: UnoSymbolPainter(symbol: UnoSymbol.skip, color: hex)),
        );
      case CardType.reverse:
        return SizedBox(
          width: width * 0.66,
          height: width * 0.66,
          child: CustomPaint(painter: UnoSymbolPainter(symbol: UnoSymbol.reverse, color: hex)),
        );
      case CardType.drawTwo:
        return SizedBox(
          width: width * 0.66,
          height: width * 0.66,
          child: CustomPaint(painter: UnoSymbolPainter(symbol: UnoSymbol.twoCards, color: hex)),
        );
      case CardType.wildDrawFour:
        return _StrokedText(
          '+4',
          fontSize: width * 0.56,
          fillColor: hex,
          strokeColor: const Color(0x40000000),
          strokeWidth: width * 0.014,
        );
      case CardType.wild:
        return SizedBox(
          width: width * 0.66,
          height: width * 0.66,
          child: const CustomPaint(painter: UnoSymbolPainter(symbol: UnoSymbol.wild)),
        );
    }
  }

  String _cornerSymbol(UnoCard c, bool isWildUnselected) {
    if (isWildUnselected && c.type == CardType.wildDrawFour) return '+4';
    switch (c.type) {
      case CardType.number:
        return '${c.value}';
      case CardType.skip:
        return 'Ø';
      case CardType.reverse:
        return '⇄';
      case CardType.drawTwo:
        return '+2';
      case CardType.wild:
        return '';
      case CardType.wildDrawFour:
        return '+4';
    }
  }

  Widget _cornerText(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: width * 0.22,
        height: 1,
        shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 1)],
      ),
    );
  }
}

/// Basit bir "text-stroke" efekti: aynı metni önce kalın kontur, sonra dolgu
/// olarak üst üste çizer (CSS `-webkit-text-stroke`'un Flutter karşılığı).
class _StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color fillColor;
  final Color strokeColor;
  final double strokeWidth;
  final bool italic;

  const _StrokedText(
    this.text, {
    required this.fontSize,
    required this.fillColor,
    required this.strokeColor,
    required this.strokeWidth,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      height: 1,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        Text(text, style: base.copyWith(color: fillColor)),
      ],
    );
  }
}
