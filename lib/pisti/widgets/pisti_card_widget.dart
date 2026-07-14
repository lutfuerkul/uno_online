import 'package:flutter/material.dart';

import '../models/pisti_card.dart';

/// Bir iskambil kağıdını (veya arka yüzünü) çizen görsel bileşen.
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
    this.width = 64,
  });

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    final showBack = faceDown || card == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: showBack ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlighted ? Colors.amber : Colors.black26,
            width: highlighted ? 3 : 1.5,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Center(
          child: showBack
              ? const Text(
                  '🂠',
                  style: TextStyle(color: Colors.white70, fontSize: 22),
                )
              : Text(
                  '${card!.rankLabel}\n${card!.suitSymbol}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: card!.isRed ? Colors.red.shade700 : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: width * 0.26,
                    height: 1.1,
                  ),
                ),
        ),
      ),
    );
  }
}
