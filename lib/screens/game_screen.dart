import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/uno_card.dart';
import '../providers/game_provider.dart';
import '../widgets/card_widget.dart';

/// Oyun ekranı: bekleme odası, oyun tahtası ve bitiş durumunu yönetir.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Oda: ${provider.gameId ?? ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: provider.leaveGame,
        ),
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : state.status == 'waiting'
              ? _WaitingRoom(code: provider.gameId!)
              : state.status == 'finished'
                  ? _Result()
                  : _Board(),
    );
  }
}

/// Oyun bitince kazanan/kaybeden sonucunu gösterir.
class _Result extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final won = provider.iWon;
    final winnerName = provider.state?.winner == provider.playerId
        ? 'Sen'
        : provider.opponentName;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? '🎉' : '😔',
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 16),
          Text(
            won ? 'Kazandın!' : 'Kaybettin',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('$winnerName oyunu kazandı.'),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: provider.leaveGame,
            child: const Text('Ana menüye dön'),
          ),
        ],
      ),
    );
  }
}

/// İkinci oyuncu katılana kadar oda kodunu gösteren bekleme ekranı.
class _WaitingRoom extends StatelessWidget {
  final String code;
  const _WaitingRoom({required this.code});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Rakip bekleniyor...', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 24),
          const Text('Bu kodu arkadaşınla paylaş:'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kod kopyalandı')),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

/// Asıl oyun tahtası.
class _Board extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final state = provider.state!;
    final top = state.topCard;

    return Column(
      children: [
        // --- Rakip ---
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                provider.opponentName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  provider.opponentCardCount.clamp(0, 12),
                  (_) => const CardWidget(faceDown: true, width: 34),
                ),
              ),
              Text('${provider.opponentCardCount} kart'),
            ],
          ),
        ),

        // --- Orta alan: geçerli renk, atılan kart, çekme destesi ---
        Expanded(
          child: Container(
            color: CardWidget.colorFor(state.currentColor).withOpacity(0.12),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Deste'),
                      const SizedBox(height: 6),
                      CardWidget(
                        faceDown: true,
                        width: 80,
                        onTap: provider.isMyTurn ? provider.drawCard : null,
                      ),
                      const SizedBox(height: 6),
                      Text(provider.isMyTurn ? 'Çekmek için dokun' : ''),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Açık kart'),
                      const SizedBox(height: 6),
                      CardWidget(card: top, width: 80),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- Sıra göstergesi ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: provider.isMyTurn
              ? Colors.green.shade100
              : Colors.grey.shade200,
          child: Text(
            provider.isMyTurn ? '● Sıra sende' : '○ Rakibin sırası',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),

        // --- Kendi elin ---
        Container(
          height: 130,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final card in provider.myHand)
                CardWidget(
                  card: card,
                  width: 68,
                  highlighted: provider.canPlay(card),
                  onTap: () => _tryPlay(context, provider, card),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _tryPlay(
    BuildContext context,
    GameProvider provider,
    UnoCard card,
  ) async {
    if (!provider.isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sıra sende değil.')),
      );
      return;
    }
    if (!provider.canPlay(card)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu kart oynanamaz.')),
      );
      return;
    }

    CardColor? chosen;
    if (card.isWild) {
      chosen = await _pickColor(context);
      if (chosen == null) return; // iptal
    }
    await provider.playCard(card, chosenColor: chosen);
  }

  /// Joker sonrası renk seçtiren diyalog.
  Future<CardColor?> _pickColor(BuildContext context) {
    return showDialog<CardColor>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renk seç'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final c in [
              CardColor.red,
              CardColor.yellow,
              CardColor.green,
              CardColor.blue,
            ])
              GestureDetector(
                onTap: () => Navigator.pop(ctx, c),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CardWidget.colorFor(c),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

