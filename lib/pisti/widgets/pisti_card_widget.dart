import 'package:flutter/material.dart';

import '../models/pisti_card.dart';
import '../theme/pisti_theme.dart';
import 'pisti_back_pattern_painter.dart';
import 'pisti_court_painter.dart';

/// Bir iskambil kağıdını (veya arka yüzünü) çizer — `docs/pisti/game.js`'teki
/// `cardHtml()` ile birebir aynı görsel dili kullanır: klasik beyaz kart
/// yüzü, köşelerde rütbe+takım, sayı kartlarında büyük takım sembolü,
/// Vale/Kız/Papaz'da taç+yüz figürlü panel.
class PistiCardWidget extends StatelessWidget {
  final PistiCard? card;

  /// true ise kartın arka yüzü gösterilir (rakiplerin elindeki kartlar için).
  final bool faceDown;
  final bool highlighted;
  final VoidCallback? onTap;
  final double width;

  const PistiCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 62,
  });

  bool get _isFaceDown => faceDown || card == null;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.45;

    Widget body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        boxShadow: const [
          BoxShadow(color: Color(0x70000000), blurRadius: 5, offset: Offset(0, 2)),
        ],
        border: _isFaceDown
            ? Border.all(color: PistiColors.cardBackBorder, width: width * 0.055)
            : Border.all(color: const Color(0x22000000), width: 1),
        color: _isFaceDown ? PistiColors.cardBackBg : PistiColors.cardFaceBg,
      ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack() : _buildFace(card!),
    );

    if (highlighted && !_isFaceDown && card != null) {
      body = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.12 + width * 0.045),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.9), spreadRadius: width * 0.03),
          ],
        ),
        margin: EdgeInsets.all(width * 0.045),
        child: body,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: highlighted ? 0 : 3),
        child: body,
      ),
    );
  }

  Widget _buildBack() {
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

  Widget _buildFace(PistiCard c) {
    final color = c.isRed ? PistiColors.cardFaceRed : PistiColors.cardFaceBlack;
    final isCourt = c.rank == PistiRank.jack ||
        c.rank == PistiRank.queen ||
        c.rank == PistiRank.king;

    final cornerText = Text(
      '${c.rankLabel}\n${c.suitSymbol}',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: width * 0.19,
        height: 1.05,
      ),
    );

    return Container(
      decoration: c.isJack
          ? BoxDecoration(
              border: Border.all(color: PistiColors.jackGlow, width: width * 0.045),
              borderRadius: BorderRadius.circular(width * 0.12),
            )
          : null,
      child: Stack(
        children: [
          Positioned(top: width * 0.06, left: width * 0.08, child: cornerText),
          Positioned(
            bottom: width * 0.06,
            right: width * 0.08,
            child: Transform.rotate(angle: 3.14159265359, child: cornerText),
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
                : Text(
                    c.suitSymbol,
                    style: TextStyle(color: color, fontSize: width * 0.4, height: 1),
                  ),
          ),
        ],
      ),
    );
  }
}
