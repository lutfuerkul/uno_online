import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pisti_board_controller.dart';
import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import '../theme/pisti_theme.dart';
import 'pisti_card_widget.dart';

/// Pişti tahtası — `docs/pisti/game.js`'teki `renderBoard()` ile birebir
/// aynı görsel dili kullanır. Hem online (Firestore) hem de bilgisayara
/// karşı (yerel) mod bu widget'ı [PistiBoardController] üzerinden paylaşır.
class PistiBoardView extends StatelessWidget {
  final PistiBoardController controller;
  final String roomLabel;
  final VoidCallback onLeave;

  const PistiBoardView({
    super.key,
    required this.controller,
    required this.roomLabel,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        if (state == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _Board(controller: controller, state: state, roomLabel: roomLabel, onLeave: onLeave);
      },
    );
  }
}

class _Board extends StatelessWidget {
  final PistiBoardController controller;
  final PistiGameState state;
  final String roomLabel;
  final VoidCallback onLeave;

  const _Board({
    required this.controller,
    required this.state,
    required this.roomLabel,
    required this.onLeave,
  });

  bool get _collecting => state.pendingCapture != null;
  bool get _isMyTurn => controller.isMyTurn;

  @override
  Widget build(BuildContext context) {
    final pile = state.pile;
    final top = pile.isNotEmpty ? pile.last : null;
    final deckCount = state.drawPile.length;

    return Column(
      children: [
        Container(
          color: PistiColors.topbar,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(roomLabel, style: const TextStyle(color: PistiColors.muted, fontSize: 14)),
              TextButton(
                onPressed: onLeave,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0x1AFFFFFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('Çık', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final id in controller.opponents) _OpponentTile(id: id, controller: controller, state: state)],
          ),
        ),

        Expanded(
          child: Container(
            color: PistiColors.middle,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Deste ($deckCount)', style: const TextStyle(color: PistiColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      deckCount > 0
                          ? const PistiCardWidget(faceDown: true, width: 84)
                          : _EmptySlot(width: 84),
                    ],
                  ),
                  const SizedBox(width: 22),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Yerdeki kartlar', style: TextStyle(color: PistiColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      top != null ? _TableStack(pile: pile) : _EmptySlot(width: 84),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: PistiColors.pileCountBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pile.length} kart',
                          style: const TextStyle(
                              color: PistiColors.pileCountText, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 22),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Sende', style: TextStyle(color: PistiColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text('${controller.wonCount(controller.selfId)} 🂠',
                          style: const TextStyle(color: Colors.white, fontSize: 30)),
                      if (controller.pistiCountFor(controller.selfId) > 0)
                        Text(
                          '🔥 ${controller.pistiCountFor(controller.selfId)} pişti',
                          style: const TextStyle(
                              color: PistiColors.pistiTag, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (state.lastAction != null && state.status == 'playing')
          _LastActionBanner(
            action: state.lastAction!,
            playerName: controller.opponentName(state.lastAction!.player),
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: _isMyTurn ? PistiColors.turnMine : PistiColors.turnTheirs,
          child: Text(
            _collecting
                ? '🧹 ${controller.opponentName(state.pendingCapture!.by)} masayı topluyor...'
                : (_isMyTurn ? '● Sıra sende — bir kart oyna' : '○ Sıra: ${controller.opponentName(state.currentTurn)}'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isMyTurn ? Colors.white : PistiColors.turnTheirsText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),

        Container(
          height: 140,
          color: PistiColors.hand,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final card in controller.myHand)
                PistiCardWidget(
                  card: card,
                  width: 70,
                  highlighted: _isMyTurn,
                  onTap: _isMyTurn ? () => _tryPlay(context, card) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _tryPlay(BuildContext context, PistiCard card) async {
    if (_collecting) return;
    if (!_isMyTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sıra sende değil.')),
      );
      return;
    }
    await controller.playCard(card);
  }
}

class _EmptySlot extends StatelessWidget {
  final double width;
  const _EmptySlot({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.45,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x33FFFFFF), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text('boş', style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13)),
    );
  }
}

/// Masadaki desteyi gösterir: en üstteki kart açık, altındakiler kapalı yığın
/// halinde hafifçe kaydırılmış olarak görünür.
class _TableStack extends StatelessWidget {
  final List<PistiCard> pile;
  const _TableStack({required this.pile});

  @override
  Widget build(BuildContext context) {
    final top = pile.last;
    final hidden = pile.length - 1;
    if (hidden <= 0) return PistiCardWidget(card: top, width: 84);

    return SizedBox(
      width: 84 + 10,
      height: 84 * 1.45 + 8,
      child: Stack(
        children: [
          if (hidden >= 2)
            Positioned(
              top: 0,
              left: 0,
              child: Transform.rotate(
                angle: -7 * math.pi / 180,
                child: const PistiCardWidget(faceDown: true, width: 84),
              ),
            ),
          Positioned(
            top: 4,
            left: 5,
            child: Transform.rotate(
              angle: -3.5 * math.pi / 180,
              child: const PistiCardWidget(faceDown: true, width: 84),
            ),
          ),
          Positioned(
            top: 8,
            left: 10,
            child: PistiCardWidget(card: top, width: 84),
          ),
        ],
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  final String id;
  final PistiBoardController controller;
  final PistiGameState state;

  const _OpponentTile({required this.id, required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final isTurn = state.currentTurn == id;
    final count = controller.opponentCardCount(id);
    final won = controller.wonCount(id);
    final pisti = controller.pistiCountFor(id);

    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isTurn ? PistiColors.oppTurnBorder : Colors.transparent, width: 2),
        color: isTurn ? PistiColors.oppTurnBg : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            controller.opponentName(id),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          _OverlappingOpponentCards(
            count: count,
            cardWidth: 34,
            overlap: 21,
            cardBuilder: () => const PistiCardWidget(faceDown: true, width: 34),
          ),
          Text('$won', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          if (pisti > 0)
            Text('🔥 $pisti pişti',
                style: const TextStyle(color: PistiColors.pistiTag, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LastActionBanner extends StatelessWidget {
  final PistiLastAction action;
  final String playerName;
  const _LastActionBanner({required this.action, required this.playerName});

  @override
  Widget build(BuildContext context) {
    if (action.isPisti) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: PistiColors.pistiBannerBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '🎉 $playerName PİŞTİ yaptı! (${action.card.nameTr})',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: PistiColors.pistiBannerText, fontSize: 17, fontWeight: FontWeight.w900),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Text(
        '$playerName ${action.card.nameTr} oynadı${action.captured ? ' — yaktı! 🔥' : ''}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: PistiColors.lastAction, fontSize: 16.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Rakip kartlarını web'deki `margin-left: -21px` ile aynı şekilde üst üste
/// bindirir. Flutter'da negatif padding yasak olduğu için Stack kullanılır.
class _OverlappingOpponentCards extends StatelessWidget {
  final int count;
  final double cardWidth;
  final double overlap;
  final Widget Function() cardBuilder;

  const _OverlappingOpponentCards({
    required this.count,
    required this.cardWidth,
    required this.overlap,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final n = math.min(count, 4);
    if (n <= 0) return const SizedBox.shrink();
    final step = cardWidth - overlap;
    final height = cardWidth * 1.5;
    return SizedBox(
      width: cardWidth + (n - 1) * step,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            Positioned(left: i * step, child: cardBuilder()),
        ],
      ),
    );
  }
}
