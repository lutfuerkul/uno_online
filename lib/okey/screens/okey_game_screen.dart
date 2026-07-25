import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/ui_scale.dart';
import '../providers/okey_online_provider.dart';
import '../services/okey_engine.dart';
import '../theme/okey_theme.dart';
import '../widgets/okey_board_view.dart';
import '../widgets/okey_exit_dialog.dart';
import '../widgets/okey_hand_reveal_view.dart';
import '../widgets/okey_result_view.dart';

/// Online oyun ekranı: bekleme odası, oyun tahtası ve bitiş durumu.
class OkeyGameScreen extends StatelessWidget {
  const OkeyGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OkeyOnlineProvider>();
    final state = provider.state;

    // Bu ekran zaten bir oda/oyun içindeyken gösterilir; sistem geri tuşu
    // doğrudan çıkmasın, onay istesin.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await confirmLeaveOkeyGame(context);
        if (leave) await provider.leaveGame();
      },
      child: Scaffold(
        backgroundColor: OkeyColors.background,
        body: SafeArea(
          child: state == null
              ? const Center(child: CircularProgressIndicator())
              : state.status == 'waiting'
                  ? const _Lobby()
                  : const _GameBody(),
        ),
      ),
    );
  }
}

class _GameBody extends StatefulWidget {
  const _GameBody();

  @override
  State<_GameBody> createState() => _GameBodyState();
}

class _GameBodyState extends State<_GameBody> {
  /// Kazanan varsa eli birkaç saniye gösterilir; berabere ise kısa gecikmeyle
  /// doğrudan skor ekranına geçilir.
  static const _handRevealDuration = Duration(seconds: 7);
  static const _drawDelay = Duration(milliseconds: 1600);

  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OkeyOnlineProvider>();
    final state = provider.state;
    final finished = state?.status == 'finished';

    if (finished) {
      final s = state!;
      final hasWinner = s.winner != null || s.winners.isNotEmpty;
      _resultTimer ??=
          Timer(hasWinner ? _handRevealDuration : _drawDelay, () {
        if (mounted) setState(() => _showResult = true);
      });
      if (_showResult) {
        return OkeyResultView(
          controller: provider,
          onRematch: provider.rematch,
          onLeave: provider.leaveGame,
        );
      }
      if (hasWinner) {
        return OkeyHandRevealView(controller: provider, state: s);
      }
    } else {
      _resultTimer?.cancel();
      _resultTimer = null;
      _showResult = false;
    }

    return OkeyBoardView(
      controller: provider,
      roomLabel: 'Oda: ${provider.gameId ?? ''}',
      onLeave: provider.leaveGame,
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OkeyOnlineProvider>();
    final state = provider.state!;
    final players = state.players;
    final isHost = provider.isHost;
    final canStart = OkeyEngine.allowedPlayerCounts.contains(players.length);

    // Tüm ölçüler tahtalardaki tek-katsayı yaklaşımıyla (bkz. computeUiScale)
    // ekrana göre orantılı ölçeklenir.
    return LayoutBuilder(builder: (context, constraints) {
      final s = computeUiScale(constraints);
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24 * s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bekleme Odası',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20 * s,
                    fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8 * s),
              Text('Bu kodu paylaş:',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 14 * s)),
              SizedBox(height: 8 * s),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: provider.gameId ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kopyalandı ✓')),
                  );
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 26 * s, vertical: 14 * s),
                  decoration: BoxDecoration(
                    color: OkeyColors.codeBoxBg,
                    border: Border.all(color: OkeyColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(14 * s),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.gameId ?? '',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40 * s,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Text('📋', style: TextStyle(fontSize: 22 * s)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20 * s),
              SizedBox(
                width: 320 * s,
                child: Column(
                  children: [
                    for (final p in players)
                      Container(
                        margin: EdgeInsets.only(bottom: 6 * s),
                        padding: EdgeInsets.symmetric(
                            horizontal: 14 * s, vertical: 10 * s),
                        decoration: BoxDecoration(
                          color: OkeyColors.lobbyRowBg,
                          borderRadius: BorderRadius.circular(10 * s),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(state.playerNames[p] ?? 'Oyuncu',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 14 * s)),
                            Text(
                              [
                                if (players.isNotEmpty && players.first == p)
                                  'kurucu',
                                if (p == provider.playerId) 'sen',
                              ].join(' · '),
                              style: TextStyle(
                                  color: OkeyColors.muted, fontSize: 13 * s),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8 * s),
              Text(
                '${players.length}/${OkeyOnlineProvider.maxPlayers} oyuncu',
                style: TextStyle(color: OkeyColors.muted, fontSize: 14 * s),
              ),
              SizedBox(height: 16 * s),
              if (isHost) ...[
                SizedBox(
                  width: 260 * s,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OkeyColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14 * s),
                    ),
                    onPressed: canStart ? provider.startGame : null,
                    child:
                        Text('Oyunu Başlat', style: TextStyle(fontSize: 14 * s)),
                  ),
                ),
                if (players.length < OkeyEngine.minPlayers)
                  Padding(
                    padding: EdgeInsets.only(top: 8 * s),
                    child: Text('En az 2 oyuncu gerekiyor',
                        style: TextStyle(
                            color: OkeyColors.muted, fontSize: 13 * s)),
                  ),
              ] else ...[
                Text('Kurucu başlatınca oyun başlayacak...',
                    style: TextStyle(color: OkeyColors.muted, fontSize: 14 * s)),
                SizedBox(height: 12 * s),
                SizedBox(
                  width: 34 * s,
                  height: 34 * s,
                  child: const CircularProgressIndicator(
                      strokeWidth: 4, color: OkeyColors.primary),
                ),
              ],
              SizedBox(height: 20 * s),
              SizedBox(
                width: 200 * s,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                  ),
                  onPressed: provider.leaveGame,
                  child: Text('Çık', style: TextStyle(fontSize: 14 * s)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
