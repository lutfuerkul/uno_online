import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../theme/uno_theme.dart';

/// Bir UNO kartını (veya arka yüzünü) çizer. Kart yüzleri, tasarım
/// SVG'lerinden (`uno_kartlari_on_yuz.svg`, `uno_ozel_kartlar_v6.svg`,
/// `uno_kart_arka_yuz.svg`) `tool/split_uno_cards.py` ile üretilen
/// `assets/uno_cards/*.png` görsellerinden gelir — Pişti'deki
/// `docs/pisti/cards/` yaklaşımının aynısı.
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

  static Color colorFor(CardColor c) => UnoColors.forCard(c);

  bool get _isFaceDown => faceDown || card == null;

  /// `assets/uno_cards/` içindeki dosya adı (uzantısız).
  String get _assetName {
    if (_isFaceDown) return 'back';
    final c = card!;
    switch (c.type) {
      case CardType.number:
        return '${c.color.name}_${c.value}';
      case CardType.skip:
        return '${c.color.name}_skip';
      case CardType.reverse:
        return '${c.color.name}_reverse';
      case CardType.drawTwo:
        return '${c.color.name}_draw2';
      case CardType.wild:
        return 'wild';
      case CardType.wildDrawFour:
        return 'wild_draw4';
    }
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
    // Görsellerdeki dış çerçeve 120 birim genişlikte 14 birim yuvarlatılmış.
    final radius = BorderRadius.circular(width * 14 / 120);

    final overrideColor = (!_isFaceDown && card!.isWild && chosenColorOverride != null)
        ? UnoColors.forCard(chosenColorOverride!)
        : null;

    final body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: _cardShadows(width),
      ),
      foregroundDecoration: overrideColor == null
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: overrideColor, width: width * 0.08),
            ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/uno_cards/$_assetName.png',
        width: width,
        height: height,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: body,
    );
  }
}
