import 'package:flutter/material.dart';

import '../models/okey_tile.dart';
import '../theme/okey_theme.dart';

/// Bir Okey taşını çizer. Taş yüzleri gerçek taş fotoğrafından kesilmiş
/// görsellerden gelir (`assets/okey/tiles/`, ör. `red_7.png`, `joker.png`).
/// Kapalı arka yüz (deste / rakip taşları) programatik çizilir.
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

  /// Gerçek taş fotoğrafının en-boy oranı (56×76 kesim).
  static const double aspect = 76 / 56;

  bool get _isFaceDown => faceDown || tile == null;

  static String _assetFor(OkeyTile t) => t.isFakeJoker
      ? 'assets/okey/tiles/joker.png'
      : 'assets/okey/tiles/${t.color.name}_${t.number}.png';

  @override
  Widget build(BuildContext context) {
    final height = width * aspect;
    final radius = width * 0.14;

    Widget face;
    if (_isFaceDown) {
      face = _buildBack(width, radius);
    } else {
      face = Image.asset(
        _assetFor(tile!),
        width: width,
        height: height,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        semanticLabel: tile!.nameTr,
      );
    }

    Widget body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          face,
          // Okey (joker) vurgusu: altın çerçeve.
          if (isOkey && !_isFaceDown)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: OkeyColors.okeyGlow,
                    width: width * 0.09,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (dimmed && !_isFaceDown) {
      body = Opacity(opacity: 0.55, child: body);
    }
    if (selected) {
      body = Transform.translate(offset: Offset(0, -width * 0.24), child: body);
    }

    return GestureDetector(onTap: onTap, child: body);
  }

  Widget _buildBack(double width, double radius) {
    return Container(
      width: width,
      height: width * aspect,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: OkeyColors.tileBackBg,
        border: Border.all(color: OkeyColors.tileBackBorder, width: width * 0.05),
      ),
      alignment: Alignment.center,
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
}
