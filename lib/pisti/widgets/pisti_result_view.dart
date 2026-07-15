import 'package:flutter/material.dart';

import '../models/pisti_board_controller.dart';
import '../models/pisti_game_state.dart';
import '../theme/pisti_theme.dart';

/// Oyun bitiş ekranı (puan tablosu) — `docs/pisti/game.js`'teki
/// `renderResult()` ile birebir aynı. Hem online hem bilgisayara karşı
/// modda ortak kullanılır.
class PistiResultView extends StatelessWidget {
  final PistiBoardController controller;
  final VoidCallback onRematch;
  final VoidCallback onLeave;

  const PistiResultView({
    super.key,
    required this.controller,
    required this.onRematch,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final winners = state.winners.isNotEmpty ? state.winners : (state.winner != null ? [state.winner!] : <String>[]);
    final iWon = winners.contains(controller.selfId);
    final tie = winners.length > 1;
    final title = tie ? 'Berabere!' : (iWon ? 'Kazandın!' : 'Kaybettin');
    final emoji = tie ? '🤝' : (iWon ? '🎉' : '😔');

    final players = [...state.players]
      ..sort((a, b) => (state.scores[b] ?? 0).compareTo(state.scores[a] ?? 0));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 360,
              child: Column(
                children: [
                  for (final p in players)
                    _ScoreRow(
                      name: controller.opponentName(p),
                      isMe: p == controller.selfId,
                      won: winners.contains(p),
                      detail: state.scoreDetail[p],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PistiColors.primary,
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
              style: TextStyle(color: PistiColors.muted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final bool isMe;
  final bool won;
  final PistiScoreDetail? detail;

  const _ScoreRow({required this.name, required this.isMe, required this.won, required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final parts = <String>[];
    if (d != null) {
      parts.add('${d.cardCount} kart');
      if (d.mostCards) parts.add('en çok kart +3');
      if (d.pisti > 0) parts.add('${d.pisti} pişti +${d.pisti * 10}');
      if (d.jackCount > 0) parts.add('${d.jackCount} vale +${d.jackCount}');
      if (d.aceCount > 0) parts.add('${d.aceCount} as +${d.aceCount}');
      if (d.clubTwoCount > 0) parts.add('sinek 2 +${d.clubTwoCount * 2}');
      if (d.diamondTenCount > 0) parts.add('karo 10 +${d.diamondTenCount * 3}');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: won ? PistiColors.scoreWinBg : PistiColors.scoreRowBg,
        borderRadius: BorderRadius.circular(12),
        border: won ? Border.all(color: PistiColors.oppTurnBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${won ? '👑 ' : ''}$name${isMe ? ' (sen)' : ''}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              Text('${d?.total ?? 0} puan',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ],
          ),
          if (parts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                parts.join(' · '),
                style: const TextStyle(color: PistiColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
