import 'package:flutter/material.dart';

import '../models/okey_tile.dart';
import '../theme/okey_theme.dart';

/// Bir Okey taşını (ya da kapalı arka yüzünü) çizer. Fildişi zemin, renkli
/// sayı ve alttaki küçük çentik ekteki gerçek taşlara benzer görünür. Sahte
/// okey bir yıldızla gösterilir.
class OkeyTileWidget extends StatelessWidget {
  final OkeyTile? tile;
  final bool faceDown;

  /// Bu taş bu elde okey (joker) mi? Altın bir çerçeveyle vurgulanır.
  final bool isOkey;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final double width;

  const OkeyTileWidget({
    super.key,
    this.tile,
    this.faceDown = false,
    this.isOkey = false,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.width = 42,
  });

  bool get _isFaceDown => faceDown || tile == null;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final radius = width * 0.16;

    Widget body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: _isFaceDown
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [OkeyColors.tileFaceHi, OkeyColors.tileFace],
              ),
        color: _isFaceDown ? OkeyColors.tileBackBg : null,
        border: Border.all(
          color: isOkey
              ? OkeyColors.okeyGlow
              : (_isFaceDown
                  ? OkeyColors.tileBackBorder
                  : const Color(0x22000000)),
          width: isOkey ? width * 0.08 : width * 0.04,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack(width) : _buildFace(tile!, width, height),
    );

    if (dimmed && !_isFaceDown) {
      body = Opacity(opacity: 0.5, child: body);
    }

    if (selected) {
      body = Transform.translate(offset: Offset(0, -width * 0.22), child: body);
    }

    return GestureDetector(
      onTap: onTap,
      child: body,
    );
  }

  Widget _buildBack(double width) {
    return Center(
      child: Container(
        width: width * 0.5,
        height: width * 0.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x66FFFFFF), width: width * 0.03),
        ),
      ),
    );
  }

  Widget _buildFace(OkeyTile t, double width, double height) {
    if (t.isFakeJoker) {
      return Center(
        child: Text(
          '★',
          style: TextStyle(
            fontSize: width * 0.7,
            height: 1,
            color: const Color(0xFFC62828),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final numberColor = OkeyColors.tileNumberColor(t.color);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: height * 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: Text(
                  '${t.number}',
                  style: TextStyle(
                    color: numberColor,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          // Alt çentik (gerçek taşlardaki oval oyuk).
          Container(
            width: width * 0.26,
            height: width * 0.26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: OkeyColors.tileNub,
            ),
          ),
        ],
      ),
    );
  }
}
