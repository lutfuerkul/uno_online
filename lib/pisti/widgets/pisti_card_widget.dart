import 'package:flutter/material.dart';

import '../models/pisti_card.dart';
import '../theme/pisti_theme.dart';
import 'pisti_back_pattern_painter.dart';
import 'pisti_court_painter.dart';
import 'pisti_suit_painter.dart';

/// Bir iskambil kağıdını (veya arka yüzünü) çizer — `docs/pisti/game.js`'teki
/// `cardHtml()` ile birebir aynı görsel dili kullanır: klasik beyaz kart
/// yüzü, köşelerde rütbe+takım, sayı kartlarında büyük takım sembolü,
/// Vale/Kız/Papaz'da taç+yüz figürlü panel.
class PistiCardWidget extends StatefulWidget {
  final PistiCard? card;

  /// true ise kartın arka yüzü gösterilir (rakiplerin elindeki kartlar için).
  final bool faceDown;

  /// Sıra sende değilken web'deki `.card.face.dim { opacity: .55 }` ile aynı.
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
    final height = width * 1.45;
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
            : Border.all(color: const Color(0x22000000), width: 1),
        color: _isFaceDown ? PistiColors.cardBackBg : PistiColors.cardFaceBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack(width) : _buildFace(c!, width),
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

  Widget _buildCorner(PistiCard c, double width, Color color) {
    final rankSize = width * 0.19;
    final suitSize = width * 0.19;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          c.rankLabel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: rankSize,
            height: 1.05,
          ),
        ),
        PistiSuitGlyph(suit: c.suit, size: suitSize, color: color),
      ],
    );
  }

  Widget _buildFace(PistiCard c, double width) {
    final color = c.isRed ? PistiColors.cardFaceRed : PistiColors.cardFaceBlack;
    final isCourt = c.rank == PistiRank.jack ||
        c.rank == PistiRank.queen ||
        c.rank == PistiRank.king;

    final corner = _buildCorner(c, width, color);

    return Stack(
      children: [
        Positioned(top: width * 0.06, left: width * 0.08, child: corner),
        Positioned(
          bottom: width * 0.06,
          right: width * 0.08,
          child: Transform.rotate(angle: 3.14159265359, child: corner),
        ),
        Center(
          child: isCourt
              ? Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: width * 0.2,
                    horizontal: width * 0.12,
                  ),
                  child: AspectRatio(
                    aspectRatio: 100 / 150,
                    child: CustomPaint(painter: PistiCourtPainter(rank: c.rank)),
                  ),
                )
              : PistiSuitGlyph(
                  suit: c.suit,
                  size: width * 0.4,
                  color: color,
                ),
        ),
      ],
    );
  }
}
