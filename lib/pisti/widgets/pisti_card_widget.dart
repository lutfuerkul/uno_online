import 'package:flutter/material.dart';

import '../models/pisti_card.dart';
import '../theme/pisti_theme.dart';
import 'pisti_back_pattern_painter.dart';

/// Bir iskambil kağıdını (veya arka yüzünü) çizer. Kart yüzleri web ile
/// ortak görsellerden gelir (`docs/pisti/cards/`, ör. `SA.webp` = Maça As);
/// `docs/pisti/game.js`'teki `cardHtml()` da aynı dosyaları kullandığı için
/// kartlar iki platformda birebir aynı görünür.
class PistiCardWidget extends StatefulWidget {
  final PistiCard? card;
  final bool faceDown;
  final bool dimmed;
  final VoidCallback? onTap;
  final double width;

  const PistiCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.dimmed = false,
    this.onTap,
    this.width = 62,
  });

  @override
  State<PistiCardWidget> createState() => _PistiCardWidgetState();
}

class _PistiCardWidgetState extends State<PistiCardWidget> {
  bool _pressed = false;

  bool get _isFaceDown => widget.faceDown || widget.card == null;

  @override
  Widget build(BuildContext context) {
    final width = widget.width;
    // 1.4: docs/pisti/cards/ içindeki kart görsellerinin en-boy oranı.
    final height = width * 1.4;
    final c = widget.card;
    final isJack = !_isFaceDown && c != null && c.isJack;

    Widget body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        boxShadow: isJack
            ? [
                BoxShadow(
                  color: PistiColors.jackGlow,
                  spreadRadius: width * 0.045,
                  blurRadius: 0,
                ),
                const BoxShadow(color: Color(0x70000000), blurRadius: 6, offset: Offset(0, 2)),
              ]
            : const [
                BoxShadow(color: Color(0x70000000), blurRadius: 5, offset: Offset(0, 2)),
              ],
        border: _isFaceDown
            ? Border.all(color: PistiColors.cardBackBorder, width: width * 0.055)
            : null,
        color: _isFaceDown ? PistiColors.cardBackBg : PistiColors.cardFaceBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack(width) : _buildFace(c!),
    );

    if (widget.dimmed && !_isFaceDown) {
      body = Opacity(opacity: 0.55, child: body);
    }

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: Transform.translate(
        offset: Offset(0, _pressed ? 2 : 0),
        child: body,
      ),
    );
  }

  Widget _buildBack(double width) {
    return Padding(
      padding: EdgeInsets.all(width * 0.07),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x77FFFFFF)),
          borderRadius: BorderRadius.circular(width * 0.06),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: PistiBackPatternPainter(tile: width * 0.2),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  static String _suitLetter(PistiSuit suit) {
    switch (suit) {
      case PistiSuit.spades:
        return 'S';
      case PistiSuit.hearts:
        return 'H';
      case PistiSuit.diamonds:
        return 'D';
      case PistiSuit.clubs:
        return 'C';
    }
  }

  Widget _buildFace(PistiCard c) {
    return Image.asset(
      'docs/pisti/cards/${_suitLetter(c.suit)}${c.rankLabel}.webp',
      fit: BoxFit.fill,
      semanticLabel: c.nameTr,
    );
  }
}
