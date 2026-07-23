import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/uno_board_controller.dart';
import '../models/uno_card.dart';
import '../theme/uno_theme.dart';
import '../widgets/player_photo_frame.dart';
import 'card_widget.dart';

const _colorTr = {
  CardColor.red: 'Kırmızı',
  CardColor.yellow: 'Sarı',
  CardColor.green: 'Yeşil',
  CardColor.blue: 'Mavi',
};

// Eli renk gruplarına göre dizmek için sıra değerleri — `docs/uno/game.js`
// `sortedHand()` ile aynı düzen (kırmızı, sarı, yeşil, mavi, jokerler en
// sonda; renk içinde önce sayılar, sonra aksiyon kartları).
const _handColorOrder = {
  CardColor.red: 0,
  CardColor.yellow: 1,
  CardColor.green: 2,
  CardColor.blue: 3,
  CardColor.wild: 4,
};
const _handTypeOrder = {
  CardType.number: 0,
  CardType.skip: 1,
  CardType.reverse: 2,
  CardType.drawTwo: 3,
  CardType.wild: 0,
  CardType.wildDrawFour: 1,
};

/// Yalnızca görüntüleme sırası — oyun durumundaki el değişmez; açılışta ve
/// sonradan çekilen kartlar hep kendi renk grubunun yanına oturur.
List<UnoCard> sortedHand(List<UnoCard> hand) {
  return [...hand]..sort((a, b) {
      final byColor = _handColorOrder[a.color]!.compareTo(_handColorOrder[b.color]!);
      if (byColor != 0) return byColor;
      final byType = _handTypeOrder[a.type]!.compareTo(_handTypeOrder[b.type]!);
      if (byType != 0) return byType;
      return (a.value ?? 0).compareTo(b.value ?? 0);
    });
}

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

        // --- Rakipler (sığmazsa yatay kaydır) ---
        Padding(
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, id) in controller.opponents.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _OpponentTile(id: id, controller: controller, state: state),
                ],
              ],
            ),
          ),
        ),

        // --- Orta alan ---
        Expanded(
          child: Container(
            color: UnoColors.forCard(state.currentColor).withOpacity(0.13),
            child: Stack(
              children: [
                // FittedBox: kısa/dar ekranlarda (küçük telefon, büyük
                // görüntü ölçeği) orta alan dikeyde sığmazsa taşmak yerine
                // orantılı küçülür. Sağdaki fotoğrafa (70px + 16px boşluk =
                // 86px) yer açmak için hafif sola kaydırılmış.
                Padding(
                  padding: const EdgeInsets.only(right: 90),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Deste', style: TextStyle(color: Colors.white, fontSize: 12)),
                            const SizedBox(height: 6),
                            CardWidget(
                              faceDown: true,
                              width: 84,
                              onTap: _isMyTurn && !state.hasDrawn ? controller.drawCard : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isMyTurn ? (state.hasDrawn ? 'çektin' : 'çekmek için dokun') : '',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Açık kart', style: TextStyle(color: Colors.white, fontSize: 12)),
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
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
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
                ),
                // Kendi fotoğrafım — sağ altta, ekranın kenarına ve alttaki
                // bilgi/sıra banner'ına tam yaslanmadan hafif ayrık (ikisinden
                // de eşit boşlukla).
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: PlayerPhotoFrame(
                    base64Photo: controller.opponentPhoto(controller.selfId),
                    size: 70,
                    borderColor: UnoColors.yellow,
                    backgroundColor: UnoColors.wildCard,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Her zaman aynı slotta kalır (yazı yokken de boş satır olarak) —
        // aksi halde metin görünüp kaybolunca orta alan (FittedBox) sürekli
        // yeniden ölçeklenip ekranı zıplatıyordu.
        _LastActionBanner(text: _infoBannerText(), color: _infoBannerColor()),

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
          color: UnoColors.hand,
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // SizedBox: elde hiç kart kalmadığında Row boş kalıp yüksekliği
            // sıfırlanmasın diye kart yüksekliği kadar sabit yer ayrılıyor.
            child: SizedBox(
              height: 62 * 1.5,
              child: Row(
                children: [
                  for (final (i, card) in sortedHand(controller.myHand).indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    CardWidget(
                      card: card,
                      width: 62,
                      highlighted: !_finished && controller.canPlay(card),
                      onTap: _finished ? null : () => _tryPlay(context, card),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _infoBannerText() {
    if (state.blockedPlayers.contains(controller.selfId)) return '🚫 Bloklandın';
    if (_shouldShowLastAction()) return _lastActionText();
    return '';
  }

  Color _infoBannerColor() {
    if (state.blockedPlayers.contains(controller.selfId)) return UnoColors.blockedTag;
    return UnoColors.lastAction;
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
        return '↩️ $who tekrar oynuyor';
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
            ? '${_colorTr[rc] ?? ''} ya da Joker / +4 yoksa çek/pas'
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
              // Web'deki `.picker-row` gibi tek satır. FittedBox, satır
              // dialoga sığmazsa (küçük ekran / büyük görüntü ölçeği) hepsini
              // orantılı küçültür — taşma/sarma olmaz.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final c in [CardColor.red, CardColor.yellow, CardColor.green, CardColor.blue]) ...[
                      if (c != CardColor.red) const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, c),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: UnoColors.forCard(c),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x33FFFFFF), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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
          PlayerPhotoFrame(
            base64Photo: controller.opponentPhoto(id),
            size: 70,
            borderColor: UnoColors.yellow,
            backgroundColor: UnoColors.wildCard,
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
      // FittedBox: satıra sığmayan uzun metinler (satır kaymadan/2 satıra
      // geçip yükseklik değiştirmeden) küçültülerek tek satırda kalır.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(color: color, fontSize: 16.5, fontWeight: FontWeight.w700),
        ),
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          if (reverseColor != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '↩️ ${_colorTr[reverseColor] ?? ''} ya da Joker / +4 yoksa çek/pas',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
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
