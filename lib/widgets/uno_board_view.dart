import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/uno_board_controller.dart';
import '../models/uno_card.dart';
import '../theme/uno_theme.dart';
import 'card_widget.dart';

const _colorTr = {
  CardColor.red: 'Kırmızı',
  CardColor.yellow: 'Sarı',
  CardColor.green: 'Yeşil',
  CardColor.blue: 'Mavi',
};

/// UNO tahtası — `docs/uno/game.js`'teki `renderBoard()` ile birebir aynı
/// görsel dili kullanır. Hem online (Firestore) hem de bilgisayara karşı
/// (yerel) mod bu widget'ı [UnoBoardController] üzerinden paylaşır.
class UnoBoardView extends StatelessWidget {
  final UnoBoardController controller;
  final String roomLabel;
  final VoidCallback onLeave;

  const UnoBoardView({
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
  final UnoBoardController controller;
  final GameState state;
  final String roomLabel;
  final VoidCallback onLeave;

  const _Board({
    required this.controller,
    required this.state,
    required this.roomLabel,
    required this.onLeave,
  });

  bool get _finished => state.status == 'finished';
  bool get _isMyTurn => !_finished && controller.isMyTurn;

  @override
  Widget build(BuildContext context) {
    final top = state.topCard;
    final topColorOverride = top != null && top.isWild ? state.currentColor : null;

    return Column(
      children: [
        // --- Üst çubuk ---
        Container(
          color: UnoColors.topbar,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(roomLabel, style: const TextStyle(color: UnoColors.muted, fontSize: 14)),
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

        // --- Rakipler ---
        Padding(
          padding: const EdgeInsets.all(10),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final id in controller.opponents) _OpponentTile(id: id, controller: controller, state: state)],
          ),
        ),

        // --- Orta alan ---
        Expanded(
          child: Container(
            color: UnoColors.forCard(state.currentColor).withOpacity(0.13),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Deste', style: TextStyle(color: UnoColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      CardWidget(
                        faceDown: true,
                        width: 84,
                        onTap: _isMyTurn && !state.hasDrawn ? controller.drawCard : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isMyTurn ? (state.hasDrawn ? 'çektin' : 'çekmek için dokun') : '',
                        style: const TextStyle(color: UnoColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(width: 22),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Açık kart', style: TextStyle(color: UnoColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      CardWidget(card: top, width: 84, chosenColorOverride: topColorOverride),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: UnoColors.forCard(state.currentColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0x55FFFFFF)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_colorTr[state.currentColor] ?? ''} ${state.direction == 1 ? '↻' : '↺'}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_shouldShowLastAction()) _LastActionBanner(text: _lastActionText()),
        if (state.blockedPlayers.contains(controller.selfId))
          const _LastActionBanner(text: '🚫 Bloklandın', color: UnoColors.blockedTag),

        _TurnBanner(controller: controller, state: state),

        // --- Aksiyonlar ---
        if (_isMyTurn && state.hasDrawn)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: UnoColors.btnPass,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                ),
                onPressed: controller.pass,
                child: const Text('Pas Geç ▶'),
              ),
            ),
          ),

        // --- El ---
        Container(
          height: 130,
          color: UnoColors.hand,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final card in controller.myHand)
                CardWidget(
                  card: card,
                  width: 68,
                  highlighted: !_finished && controller.canPlay(card),
                  onTap: _finished ? null : () => _tryPlay(context, card),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _shouldShowLastAction() {
    final la = state.lastAction;
    if (la == null) return false;
    if (state.status != 'playing') return false;
    if (state.discardPile.length <= 1) return false;
    return true;
  }

  String _lastActionText() {
    final la = state.lastAction;
    if (la == null) return '';
    final who = controller.opponentName(la.player);
    final tgt = la.target != null ? controller.opponentName(la.target!) : '';
    if (la.isPass) return '⏭️ $who pas geçti';
    switch (la.cardType) {
      case CardType.skip:
        return '🚫 $who → $tgt bloklandı';
      case CardType.drawTwo:
        return "➕2 $who → $tgt'e 2 kart çektirdi";
      case CardType.wildDrawFour:
        return "➕4 $who → $tgt'e 4 kart çektirdi (renk seçti)";
      case CardType.reverse:
        return '🔄 $who Reverse oynadı (tekrar oynuyor)';
      case CardType.wild:
        return '🎨 $who Joker oynadı (renk seçti)';
      case CardType.number:
        return '$who ${_colorTr[la.cardColor] ?? ''} ${la.cardValue} oynadı';
      case null:
        return '';
    }
  }

  Future<void> _tryPlay(BuildContext context, UnoCard card) async {
    if (!_isMyTurn) {
      _toast(context, 'Sıra sende değil.');
      return;
    }
    if (!controller.canPlay(card)) {
      final rc = controller.reverseColor;
      _toast(
        context,
        rc != null
            ? 'Reverse sonrası sadece ${_colorTr[rc] ?? ''}, Reverse, +2, Joker ya da +4 oynayabilirsin.'
            : 'Bu kart oynanamaz.',
      );
      return;
    }

    final finisher = controller.myHand.length == 1;

    CardColor? chosenColor;
    if (!finisher && card.isWild) {
      chosenColor = await _pickColor(context);
      if (chosenColor == null) return;
    }

    String? targetId;
    if (!finisher) {
      if (card.type == CardType.drawTwo || card.type == CardType.wildDrawFour) {
        targetId = await _pickPlayer(context, 'Kime eklensin?');
        if (targetId == null) return;
      } else if (card.type == CardType.skip) {
        targetId = await _pickPlayer(context, 'Kimi blokla?');
        if (targetId == null) return;
      }
    }

    await controller.playCard(card, chosenColor: chosenColor, targetId: targetId);
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<CardColor?> _pickColor(BuildContext context) {
    return showDialog<CardColor>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (ctx) => Dialog(
        backgroundColor: UnoColors.pickerBg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Renk seç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final c in [CardColor.red, CardColor.yellow, CardColor.green, CardColor.blue])
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, c),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: UnoColors.forCard(c),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x33FFFFFF), width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('↩ Oyuna Geri Dön', style: TextStyle(color: UnoColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rakip tek kişiyse otomatik seçilir (soru sorulmaz), matches web fallback.
  Future<String?> _pickPlayer(BuildContext context, String title) async {
    final targets = controller.opponents;
    if (targets.length == 1) return targets.first;

    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xAA000000),
      builder: (ctx) => Dialog(
        backgroundColor: UnoColors.pickerBg,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: Column(
                  children: [
                    for (final p in targets) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UnoColors.targetBtnBg,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, p),
                          child: Text(
                            '${controller.opponentName(p)} (${controller.opponentCardCount(p)} kart)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('İptal', style: TextStyle(color: UnoColors.muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpponentTile extends StatelessWidget {
  final String id;
  final UnoBoardController controller;
  final GameState state;

  const _OpponentTile({required this.id, required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final finished = state.status == 'finished';
    final isTurn = finished ? state.winner == id : state.currentTurn == id;
    final count = controller.opponentCardCount(id);
    final blocked = controller.blockedCount(id);

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isTurn ? UnoColors.oppTurnBorder : Colors.transparent, width: 2),
        color: isTurn ? UnoColors.oppTurnBg : null,
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
            cardBuilder: () => const CardWidget(faceDown: true, width: 34, showBackLogo: false),
          ),
          if (blocked > 0)
            Text(
              '🚫 bloklu${blocked > 1 ? ' ×$blocked' : ''}',
              style: const TextStyle(color: UnoColors.blockedTag, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          Text('$count kart', style: const TextStyle(color: UnoColors.muted, fontSize: 12)),
          if (count == 1)
            const Text('UNO', style: TextStyle(color: UnoColors.unoTag, fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LastActionBanner extends StatelessWidget {
  final String text;
  final Color color;
  const _LastActionBanner({required this.text, this.color = UnoColors.lastAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 16.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  final UnoBoardController controller;
  final GameState state;

  const _TurnBanner({required this.controller, required this.state});

  @override
  Widget build(BuildContext context) {
    final finished = state.status == 'finished';
    final isMyTurn = !finished && controller.isMyTurn;

    String text;
    Color bg;
    Color textColor = Colors.white;
    if (finished) {
      if (state.winner == null) {
        text = '🤝 Hamle şansı kalmadı — berabere bitti';
        bg = UnoColors.turnTheirs;
        textColor = UnoColors.turnTheirsText;
      } else if (state.winner == controller.selfId) {
        text = '🎉 Oyunu bitirdin!';
        bg = UnoColors.turnMine;
      } else {
        text = '🏆 ${controller.opponentName(state.winner!)} kazandı!';
        bg = UnoColors.turnTheirs;
        textColor = UnoColors.turnTheirsText;
      }
    } else if (isMyTurn) {
      text = '● Sıra sende';
      bg = UnoColors.turnMine;
    } else {
      text = '○ Sıra: ${controller.opponentName(state.currentTurn)}';
      bg = UnoColors.turnTheirs;
      textColor = UnoColors.turnTheirsText;
    }

    final reverseColor = !finished && isMyTurn ? controller.reverseColor : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: bg,
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (reverseColor != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '↩️ Reverse! Sadece ${_colorTr[reverseColor] ?? ''}, başka bir Reverse, +2, Joker ya da +4 oyna — yoksa çek/pas.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
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
