import 'package:flutter/material.dart';

import '../models/uno_card.dart';

/// Bir UNO kartını (veya arka yüzünü) çizen görsel bileşen.
class CardWidget extends StatelessWidget {
  final UnoCard? card;

  /// true ise kartın arka yüzü gösterilir (rakibin elindeki kartlar için).
  final bool faceDown;

  /// Oynanabilir kartları vurgulamak için çerçeve.
  final bool highlighted;

  final VoidCallback? onTap;
  final double width;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 64,
  });

  static Color colorFor(CardColor c) {
    switch (c) {
      case CardColor.red:
        return const Color(0xFFD32F2F);
      case CardColor.yellow:
        return const Color(0xFFF9A825);
      case CardColor.green:
        return const Color(0xFF388E3C);
      case CardColor.blue:
        return const Color(0xFF1976D2);
      case CardColor.wild:
        return const Color(0xFF212121);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final Color bg =
        faceDown || card == null ? const Color(0xFF37474F) : colorFor(card!.color);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? Colors.white : Colors.white24,
            width: highlighted ? 3 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: faceDown || card == null
              ? const Text(
                  'UNO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : Text(
                  card!.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: card!.type == CardType.number ? 26 : 18,
                  ),
                ),
        ),
      ),
    );
  }
}
