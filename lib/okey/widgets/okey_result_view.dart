import 'package:flutter/material.dart';

import '../models/okey_board_controller.dart';
import '../theme/okey_theme.dart';

/// Okey el bitiş ekranı. Hem online hem bilgisayara karşı modda ortak.
class OkeyResultView extends StatelessWidget {
  final OkeyBoardController controller;
  final VoidCallback onRematch;
  final VoidCallback onLeave;

  const OkeyResultView({
    super.key,
    required this.controller,
    required this.onRematch,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state!;
    final winners = state.winners.isNotEmpty
        ? state.winners
        : (state.winner != null ? [state.winner!] : <String>[]);
    final iWon = winners.contains(controller.selfId);
    final tie = winners.isEmpty;
    final title = tie ? 'Berabere!' : (iWon ? 'Kazandın!' : 'Kaybettin');
    final emoji = tie ? '🤝' : (iWon ? '🎉' : '😔');

    final winnerName =
        winners.isNotEmpty ? controller.opponentName(winners.first) : '';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 6),
            if (tie)
              const Text('Deste bitti, kimse el açamadı.',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 14))
            else
              Text(
                _finishText(winnerName, state.finishedByOkey,
                    state.finishedByPair, state.scores[winners.first] ?? 0),
                textAlign: TextAlign.center,
                style: const TextStyle(color: OkeyColors.accent, fontSize: 15),
              ),
            const SizedBox(height: 4),
            const Text('Toplam puan (oyundan çıkılmadıkça birikir):',
                style: TextStyle(color: OkeyColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              width: 360,
              child: Column(
                children: [
                  for (final p in _sortedPlayers(
                      state.players, state.cumulativeScores))
                    _scoreRow(
                      name: controller.opponentName(p),
                      isMe: p == controller.selfId,
                      won: winners.contains(p),
                      points: state.cumulativeScores[p] ?? 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 260,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: OkeyColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onRematch,
                child: const Text('🔁 Yeni El'),
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
          ],
        ),
      ),
    );
  }

  /// Bitiş satırı: normal, okey atarak (çifte), 7 çift ile (çifte) ya da
  /// ikisi birden (dörtlü puan) olma durumuna göre metni seçer.
  String _finishText(
      String winnerName, bool byOkey, bool byPair, int points) {
    if (byPair && byOkey) {
      return '$winnerName çifte (7 çift) + okey atarak bitirdi — dörtlü! (+$points)';
    }
    if (byPair) {
      return '$winnerName çifte (7 çift) ile bitirdi! (+$points)';
    }
    if (byOkey) {
      return '$winnerName okey atarak bitirdi — çifte! (+$points)';
    }
    return '$winnerName eli açtı (+$points)';
  }

  List<String> _sortedPlayers(List<String> players, Map<String, int> scores) {
    final list = [...players];
    list.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return list;
  }

  Widget _scoreRow({
    required String name,
    required bool isMe,
    required bool won,
    required int points,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: won ? OkeyColors.scoreWinBg : OkeyColors.scoreRowBg,
        borderRadius: BorderRadius.circular(12),
        border: won ? Border.all(color: OkeyColors.oppTurnBorder) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${won ? '👑 ' : ''}$name${isMe ? ' (sen)' : ''}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          Text('$points puan',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
