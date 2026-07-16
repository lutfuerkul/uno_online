import 'dart:math';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import 'deck_service.dart';

/// UNO'nun tur/kural motoru — `docs/uno/game.js`'teki playCard/drawCard/
/// pass/advanceTurn fonksiyonlarının birebir Dart karşılığı. Firestore'a mı
/// yoksa yerel belleğe mi yazıldığı bu katmanı ilgilendirmez; sadece bir
/// [GameState]'i girdi alıp yeni bir [GameState] üretir.
class UnoEngine {
  static const int startingHandSize = 7;
  static const int maxPlayers = 4;

  /// Reverse kilidi varken oynanabilir: aynı renk (+2 dahil), başka reverse,
  /// joker ya da +4.
  static bool canPlayUnderReverseLock(UnoCard card, CardColor reverseColor) {
    return card.type == CardType.reverse ||
        card.color == reverseColor ||
        card.isWild;
  }

  static bool isPlayable(UnoCard card, GameState state) {
    final top = state.topCard;
    if (top == null) return false;
    if (state.reverseColor != null) {
      return canPlayUnderReverseLock(card, state.reverseColor!);
    }
    return DeckService.canPlay(card, top, state.currentColor);
  }

  static int _nextIndex(int idx, int dir, int n, int steps) =>
      ((idx + dir * steps) % n + n) % n;

  /// Sırayı, bloklu oyuncuları atlayarak ilerletir. Birden fazla bağımsız
  /// blok üst üste binebilir; her bloklu oyuncu sırası gelince bir blok
  /// tüketilerek atlanır.
  static ({String nextTurn, List<String> blocked}) _advanceTurn(
    List<String> players,
    int curIdx,
    int dir,
    List<String> blocked,
  ) {
    final n = players.length;
    final blk = List<String>.from(blocked);
    var idx = _nextIndex(curIdx, dir, n, 1);
    var guard = 0;
    while (guard++ < n * 4) {
      final bi = blk.indexOf(players[idx]);
      if (bi == -1) break;
      blk.removeAt(bi);
      idx = _nextIndex(idx, dir, n, 1);
    }
    return (nextTurn: players[idx], blocked: blk);
  }

  static void _drawInto(
    Map<String, List<UnoCard>> hands,
    String player,
    List<UnoCard> draw,
    List<UnoCard> discard,
    int count,
  ) {
    final hand = hands[player] ?? <UnoCard>[];
    for (var i = 0; i < count; i++) {
      if (draw.isEmpty) {
        _reshuffle(draw, discard);
        if (draw.isEmpty) break;
      }
      hand.add(draw.removeLast());
    }
    hands[player] = hand;
  }

  static void _reshuffle(List<UnoCard> draw, List<UnoCard> discard) {
    if (discard.length <= 1) return;
    final top = discard.removeLast();
    draw.addAll(discard);
    draw.shuffle();
    discard
      ..clear()
      ..add(top);
  }

  /// Yeni bir oyun kurar: 7'şer kart dağıtır, ilk açık kartın sayı kartı
  /// olmasını sağlar, rastgele bir oyuncuyla başlatır.
  static GameState dealNewGame({
    required String id,
    required List<String> players,
    required Map<String, String> playerNames,
  }) {
    final deck = DeckService.buildDeck()..shuffle();
    final hands = <String, List<UnoCard>>{
      for (final p in players)
        p: [for (var i = 0; i < startingHandSize; i++) deck.removeLast()],
    };
    var first = deck.removeLast();
    while (first.isWild || first.type != CardType.number) {
      deck.insert(0, first);
      first = deck.removeLast();
    }
    return GameState(
      id: id,
      status: 'playing',
      players: players,
      playerNames: playerNames,
      hands: hands,
      drawPile: deck,
      discardPile: [first],
      currentColor: first.color,
      currentTurn: players[Random().nextInt(players.length)],
      direction: 1,
      hasDrawn: false,
      reverseColor: null,
      blockedPlayers: const [],
      winner: null,
      lastAction: null,
    );
  }

  /// Kart oynar. Kural ihlali varsa (sıra değil, kart oynanamaz, joker için
  /// renk eksik...) null döner.
  static GameState? playCard({
    required GameState state,
    required String playerId,
    required UnoCard card,
    CardColor? chosenColor,
    String? targetId,
  }) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    final hand = List<UnoCard>.from(state.hands[playerId] ?? const []);
    final idx = hand.indexWhere((c) => c.id == card.id);
    if (idx == -1) return null;

    final top = state.topCard;
    if (top == null) return null;
    final finisher = hand.length == 1;

    final inReverse = state.reverseColor != null;
    if (inReverse) {
      if (!canPlayUnderReverseLock(card, state.reverseColor!)) return null;
      if (card.isWild && chosenColor == null && !finisher) return null;
    } else {
      if (!DeckService.canPlay(card, top, state.currentColor)) return null;
      if (card.isWild && chosenColor == null && !finisher) return null;
    }

    hand.removeAt(idx);
    final discard = List<UnoCard>.from(state.discardPile)..add(card);
    final draw = List<UnoCard>.from(state.drawPile);
    final hands = {
      for (final e in state.hands.entries) e.key: List<UnoCard>.from(e.value),
    };
    hands[playerId] = hand;

    final players = state.players;
    final n = players.length;
    final curIdx = players.indexOf(playerId);
    final dir = state.direction;
    final newColor = card.isWild ? (chosenColor ?? state.currentColor) : card.color;

    String pickTarget() => (targetId != null && players.contains(targetId) && targetId != playerId)
        ? targetId
        : players[_nextIndex(curIdx, dir, n, 1)];

    var keepTurn = false;
    CardColor? nextReverseColor;
    var blocked = List<String>.from(state.blockedPlayers);
    String? effectTarget;

    if (!finisher) {
      switch (card.type) {
        case CardType.skip:
          effectTarget = pickTarget();
          blocked.add(effectTarget);
          break;
        case CardType.reverse:
          keepTurn = true;
          nextReverseColor = card.color;
          break;
        case CardType.drawTwo:
          effectTarget = pickTarget();
          _drawInto(hands, effectTarget, draw, discard, 2);
          break;
        case CardType.wildDrawFour:
          effectTarget = pickTarget();
          _drawInto(hands, effectTarget, draw, discard, 4);
          break;
        case CardType.number:
        case CardType.wild:
          break;
      }
    }

    String nextTurn;
    List<String> finalBlocked;
    if (keepTurn) {
      nextTurn = playerId;
      finalBlocked = blocked;
    } else {
      final adv = _advanceTurn(players, curIdx, dir, blocked);
      nextTurn = adv.nextTurn;
      finalBlocked = adv.blocked;
    }

    var status = state.status;
    String? winner = state.winner;
    if (hand.isEmpty) {
      status = 'finished';
      winner = playerId;
    }

    return state.copyWith(
      hands: hands,
      drawPile: draw,
      discardPile: discard,
      currentColor: newColor,
      currentTurn: nextTurn,
      hasDrawn: false,
      clearReverseColor: nextReverseColor == null,
      reverseColor: nextReverseColor,
      blockedPlayers: finalBlocked,
      status: status,
      clearWinner: winner == null,
      winner: winner,
      lastAction: UnoLastAction(
        player: playerId,
        cardType: card.type,
        cardColor: newColor,
        cardValue: card.value,
        target: effectTarget,
      ),
    );
  }

  /// Desteden 1 kart çeker. Sıra geçmez; oyuncu çektiği kartı oynayabilir ya
  /// da [pass] ile sırayı bırakabilir.
  static GameState? drawCard({required GameState state, required String playerId}) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (state.hasDrawn) return null;

    final draw = List<UnoCard>.from(state.drawPile);
    final discard = List<UnoCard>.from(state.discardPile);
    final hands = {
      for (final e in state.hands.entries) e.key: List<UnoCard>.from(e.value),
    };
    _drawInto(hands, playerId, draw, discard, 1);

    return state.copyWith(hands: hands, drawPile: draw, discardPile: discard, hasDrawn: true);
  }

  /// Kart çektikten sonra oynamak istemezse sırayı sonraki oyuncuya geçirir.
  static GameState? pass({required GameState state, required String playerId}) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (!state.hasDrawn) return null;

    final players = state.players;
    final curIdx = players.indexOf(playerId);
    final adv = _advanceTurn(players, curIdx, state.direction, state.blockedPlayers);

    return state.copyWith(
      currentTurn: adv.nextTurn,
      hasDrawn: false,
      clearReverseColor: true,
      blockedPlayers: adv.blocked,
      lastAction: UnoLastAction(player: playerId, isPass: true),
    );
  }

  /// Oyuncu odadan/oyundan ayrılır. Tek kişi kalırsa o kazanır; sırası
  /// gelen kişi çıktıysa sıra bir sonraki oyuncuya geçer.
  static GameState leavePlayer({required GameState state, required String playerId}) {
    final players = state.players.where((p) => p != playerId).toList();
    final names = Map<String, String>.from(state.playerNames)..remove(playerId);
    final hands = {
      for (final e in state.hands.entries)
        if (e.key != playerId) e.key: e.value,
    };

    if (players.isEmpty || state.status != 'playing') {
      return state.copyWith(players: players, playerNames: names, hands: hands);
    }
    if (players.length < 2) {
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        status: 'finished',
        winner: players.first,
      );
    }
    if (state.currentTurn == playerId) {
      final oldIdx = state.players.indexOf(playerId);
      final nextTurn = state.players[_nextIndex(oldIdx, state.direction, state.players.length, 1)];
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        currentTurn: nextTurn,
        hasDrawn: false,
        clearReverseColor: true,
      );
    }
    return state.copyWith(players: players, playerNames: names, hands: hands);
  }
}
