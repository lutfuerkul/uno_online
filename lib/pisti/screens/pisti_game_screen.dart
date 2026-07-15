import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pisti_game_state.dart';
import '../providers/pisti_local_provider.dart';
import '../widgets/pisti_card_widget.dart';

/// "Bilgisayara Karşı" modunda Pişti oyun tahtası.
class PistiGameScreen extends StatelessWidget {
  const PistiGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PistiLocalProvider>();
    final finished = provider.state?.status == 'finished';

    return Scaffold(
      appBar: AppBar(
        title: const Text('🃏 Pişti — Bilgisayara Karşı'),
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
              ? const _PistiResult()
              : const _PistiBoard(),
    );
  }
}

class _PistiResult extends StatelessWidget {
  const _PistiResult();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PistiLocalProvider>();
    final state = provider.state!;
    final won = state.winner == PistiLocalProvider.humanId;
    final tie = state.winner == null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tie ? '🤝' : (won ? '🎉' : '😔'),
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              tie ? 'Berabere!' : (won ? 'Kazandın!' : 'Kaybettin'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            for (final p in state.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _ScoreRow(
                  name: p == PistiLocalProvider.humanId
                      ? 'Sen'
                      : provider.opponentName(p),
                  detail: state.scoreDetail[p],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                provider.leaveGame();
                Navigator.of(context).pop();
              },
              child: const Text('Ana menüye dön'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final PistiScoreDetail? detail;
  const _ScoreRow({required this.name, required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    if (d == null) return const SizedBox.shrink();
    return Container(
      width: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('${d.total} puan (${d.cardCount} kart)'),
        ],
      ),
    );
  }
}

class _PistiBoard extends StatelessWidget {
  const _PistiBoard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PistiLocalProvider>();
    final state = provider.state!;
    final top = state.topOfPile;

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
                    const PistiCardWidget(faceDown: true, width: 30),
                    Text(
                      '${provider.opponentCardCount(id)} elde · '
                      '${provider.wonCount(id)} topladı',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // --- Masa ---
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Masa (${state.pile.length} kart)'),
                const SizedBox(height: 8),
                PistiCardWidget(card: top, width: 90),
              ],
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
                ? '● Sıra sende — ${provider.wonCount(PistiLocalProvider.humanId)} kart topladın'
                : '○ ${provider.opponentName(state.currentTurn)} oynuyor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),

        // --- Kendi elin ---
        Container(
          height: 140,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final card in provider.myHand)
                PistiCardWidget(
                  card: card,
                  width: 70,
                  highlighted: provider.isMyTurn,
                  onTap:
                      provider.isMyTurn ? () => provider.playCard(card) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
