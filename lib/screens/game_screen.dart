import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/uno_theme.dart';
import '../widgets/uno_board_view.dart';
import '../widgets/uno_result_view.dart';

/// Oyun ekranı: bekleme odası, oyun tahtası ve bitiş durumunu yönetir.
/// `docs/uno/game.js`'teki renderLobby/renderBoard/renderResult ile birebir
/// aynı görsel dili kullanır.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state;

    return Scaffold(
      backgroundColor: UnoColors.background,
      body: SafeArea(
        child: state == null
            ? const Center(child: CircularProgressIndicator())
            : state.status == 'waiting'
                ? const _Lobby()
                : const _GameBody(),
      ),
    );
  }
}

/// Oyun bitince kazananın son attığı kart görülsün diye sonuç ekranına
/// geçmeden önce 2 saniye tahtayı göstermeye devam eder (web ile aynı süre).
class _GameBody extends StatefulWidget {
  const _GameBody();

  @override
  State<_GameBody> createState() => _GameBodyState();
}

class _GameBodyState extends State<_GameBody> {
  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final finished = provider.state?.status == 'finished';

    if (finished) {
      _resultTimer ??= Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showResult = true);
      });
      if (_showResult) {
        return UnoResultView(
          controller: provider,
          onRematch: provider.rematch,
          onLeave: provider.leaveGame,
        );
      }
    } else {
      _resultTimer?.cancel();
      _resultTimer = null;
      _showResult = false;
    }

    return UnoBoardView(
      controller: provider,
      roomLabel: 'Oda: ${provider.gameId ?? ''}',
      onLeave: provider.leaveGame,
    );
  }
}

/// İkinci (ve sonraki) oyuncular katılana kadar / kurucu başlatana kadar
/// gösterilen bekleme odası.
class _Lobby extends StatelessWidget {
  const _Lobby();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state!;
    final players = state.players;
    final isHost = provider.isHost;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bekleme Odası',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Bu kodu paylaş:', style: TextStyle(color: UnoColors.muted, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: provider.gameId ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kopyalandı ✓')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                decoration: BoxDecoration(
                  color: UnoColors.codeBoxBg,
                  border: Border.all(color: UnoColors.red, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.gameId ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('📋', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 320,
              child: Column(
                children: [
                  for (final p in players)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: UnoColors.lobbyRowBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.playerNames[p] ?? 'Oyuncu',
                              style: const TextStyle(color: Colors.white)),
                          Text(
                            [
                              if (players.isNotEmpty && players.first == p) 'kurucu',
                              if (p == provider.playerId) 'sen',
                            ].join(' · '),
                            style: const TextStyle(color: UnoColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${players.length}/${GameProvider.maxPlayers} oyuncu',
              style: const TextStyle(color: UnoColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (isHost) ...[
              SizedBox(
                width: 260,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UnoColors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: players.length < 2 ? null : provider.startGame,
                  child: const Text('Oyunu Başlat'),
                ),
              ),
              if (players.length < 2)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('En az 2 oyuncu gerekiyor',
                      style: TextStyle(color: UnoColors.muted, fontSize: 13)),
                ),
            ] else ...[
              const Text('Kurucu başlatınca oyun başlayacak...',
                  style: TextStyle(color: UnoColors.muted, fontSize: 14)),
              const SizedBox(height: 12),
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(strokeWidth: 4, color: UnoColors.red),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                ),
                onPressed: provider.leaveGame,
                child: const Text('Çık'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
