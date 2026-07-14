import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/uno_card.dart';
import '../providers/local_uno_provider.dart';
import '../widgets/card_widget.dart';

/// "Bilgisayara Karşı" modunda oyun tahtası. [GameScreen] ile aynı görsel
/// dili paylaşır; farkı Firestore yerine [LocalUnoProvider] kullanması ve
/// birden fazla rakip (bot) gösterebilmesidir.
class LocalUnoGameScreen extends StatelessWidget {
  const LocalUnoGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalUnoProvider>();
    final finished = provider.state?.status == 'finished';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Bilgisayara Karşı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            provider.leaveGame();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: provider.state == null
          ? const Center(child: CircularProgressIndicator())
          : finished
              ? const _LocalResult()
              : const _LocalBoard(),
    );
  }
}

class _LocalResult extends StatelessWidget {
  const _LocalResult();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalUnoProvider>();
    final won = provider.iWon;
    final winnerId = provider.state?.winner;
    final winnerName = winnerId == LocalUnoProvider.humanId
        ? 'Sen'
        : provider.opponentName(winnerId ?? '');

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(won ? '🎉' : '😔', style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            won ? 'Kazandın!' : 'Kaybettin',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(won ? 'Sen oyunu kazandın.' : '$winnerName oyunu kazandı.'),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              provider.leaveGame();
              Navigator.of(context).pop();
            },
            child: const Text('Ana menüye dön'),
          ),
        ],
      ),
    );
  }
}

class _LocalBoard extends StatelessWidget {
  const _LocalBoard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocalUnoProvider>();
    final state = provider.state!;
    final top = state.topCard;

    return Column(
      children: [
        // --- Rakipler (botlar) ---
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              for (final id in provider.opponents)
                Column(
                  children: [
                    Text(
                      provider.opponentName(id),
                      style: TextStyle(
                        fontWeight: state.currentTurn == id
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: state.currentTurn == id
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        math.min(provider.opponentCardCount(id), 4),
                        (_) => const CardWidget(faceDown: true, width: 26),
                      ),
                    ),
                    Text(
                      '${provider.opponentCardCount(id)} kart',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
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
          color:
              provider.isMyTurn ? Colors.green.shade100 : Colors.grey.shade200,
          child: Text(
            provider.isMyTurn
                ? '● Sıra sende'
                : '○ ${provider.opponentName(state.currentTurn)} oynuyor',
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
    LocalUnoProvider provider,
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
