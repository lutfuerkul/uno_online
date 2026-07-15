import 'package:flutter/material.dart';

import '../models/uno_board_controller.dart';
import '../theme/uno_theme.dart';

/// Oyun bitiş ekranı — `docs/uno/game.js`'teki `renderResult()` ile birebir
/// aynı. Hem online hem bilgisayara karşı modda ortak kullanılır.
class UnoResultView extends StatelessWidget {
  final UnoBoardController controller;
  final VoidCallback onRematch;
  final VoidCallback onLeave;

  const UnoResultView({
    super.key,
    required this.controller,
    required this.onRematch,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final tie = state.winner == null;
    final won = !tie && state.winner == controller.selfId;
    final winnerName = won ? 'Sen' : controller.opponentName(state.winner ?? '');

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tie ? '🤝' : (won ? '🎉' : '😔'), style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(
              tie ? 'Berabere!' : (won ? 'Kazandın!' : 'Kaybettin'),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              tie
                  ? 'Hamle şansı kalmadığı için oyun berabere sonlandırıldı.'
                  : (won ? 'Sen oyunu kazandın.' : '$winnerName oyunu kazandı.'),
              style: const TextStyle(color: UnoColors.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 260,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: UnoColors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onRematch,
                child: const Text('🔁 Tekrar Oyna'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onLeave,
                child: const Text('Çık'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tekrar Oyna herkesi bekleme odasına döndürür; kurucu yeniden başlatır.',
              style: TextStyle(color: UnoColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
