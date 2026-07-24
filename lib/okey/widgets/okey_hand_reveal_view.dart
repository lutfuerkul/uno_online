import 'package:flutter/material.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_meld_solver.dart';
import '../theme/okey_theme.dart';
import 'okey_tile_widget.dart';

/// El açan (kazanan) oyuncunun elini birkaç saniye ekranda gösterir; sonuç
/// (skor) ekranına geçmeden önce herkes hangi taşlarla bitirdiğini görsün
/// diye. Yalnızca gerçek bir kazanan olduğunda (berabere değilse) gösterilir.
class OkeyHandRevealView extends StatelessWidget {
  final OkeyBoardController controller;
  final OkeyGameState state;

  const OkeyHandRevealView({
    super.key,
    required this.controller,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final winnerId =
        state.winners.isNotEmpty ? state.winners.first : state.winner;
    final winnerName =
        winnerId != null ? controller.opponentName(winnerId) : '';
    final hand = winnerId != null
        ? (state.hands[winnerId] ?? const <OkeyTile>[])
        : const <OkeyTile>[];

    // Jokerin (varsa) hangi taşın yerine kullanıldığını göstermek için elin
    // gerçek grup bölünmesini bul; bulunamazsa (olmaması gerekir) düz
    // sıralamaya düş.
    final melds = hand.length == 14
        ? OkeyMeldSolver.solveMelds(hand, state.okeyColor, state.okeyNumber)
        : null;

    final sorted = [...hand]..sort((a, b) {
        final aOkey = state.isOkey(a);
        final bOkey = state.isOkey(b);
        if (aOkey != bOkey) return aOkey ? 1 : -1;
        if (a.color.index != b.color.index) {
          return a.color.index.compareTo(b.color.index);
        }
        return a.number.compareTo(b.number);
      });

    return Container(
      color: OkeyColors.background,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  state.finishedByPair && state.finishedByOkey
                      ? '$winnerName çifte + okey atarak bitirdi!'
                      : state.finishedByPair
                          ? '$winnerName çifte (7 çift) ile bitirdi!'
                          : state.finishedByOkey
                              ? '$winnerName okey atarak bitirdi!'
                              : '$winnerName elini açtı!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Kazanan el:',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: OkeyColors.rackDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x55000000), width: 2),
                  ),
                  child: melds != null
                      ? Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final meld in melds)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFFFFF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (final tile in meld) ...[
                                      OkeyTileWidget(
                                        tile: tile,
                                        width: 36,
                                        isOkey: state.isOkey(tile),
                                      ),
                                      const SizedBox(width: 2),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        )
                      : Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final tile in sorted)
                              OkeyTileWidget(
                                tile: tile,
                                width: 36,
                                isOkey: state.isOkey(tile),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
