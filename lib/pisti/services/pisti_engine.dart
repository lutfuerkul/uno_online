import 'dart:math';

import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import 'pisti_deck_service.dart';

/// Pişti'nin tur/kural motoru — `docs/pisti/game.js`'teki playCard/
/// collectPile/dealRound/leaveRoom fonksiyonlarının birebir Dart karşılığı.
/// Firestore'a mı yoksa yerel belleğe mi yazıldığı bu katmanı ilgilendirmez;
/// sadece bir [PistiGameState]'i girdi alıp yeni bir [PistiGameState] üretir.
class PistiEngine {
  static const int minPlayers = 2;
  static const int maxPlayers = 4;
  static const allowedPlayerCounts = [2, 3, 4];

  static int _nextIndex(int idx, int n, int steps) => ((idx + steps) % n + n) % n;

  /// Yeni bir el/oyun kurar: 4'er kart dağıtır, masaya açılış kartlarını
  /// koyar, rastgele bir oyuncuyla başlatır.
  static PistiGameState dealNewGame({
    required String id,
    required List<String> players,
    required Map<String, String> playerNames,
  }) {
    final numDecks = players.length > 2 ? 2 : 1;
    final tableSize = players.length == 3 ? 5 : 4;
    final deck = PistiDeckService.buildDeck(numDecks: numDecks)..shuffle();
    final hands = PistiDeckService.dealHands(deck, players);
    final pile = PistiDeckService.dealTable(deck, tableSize);

    return PistiGameState(
      id: id,
      status: 'playing',
      players: players,
      playerNames: playerNames,
      hands: hands,
      pile: pile,
      drawPile: deck,
      won: {for (final p in players) p: <PistiCard>[]},
      pistiCount: {for (final p in players) p: 0},
      lastCapturer: null,
      currentTurn: players[Random().nextInt(players.length)],
      winner: null,
      winners: const [],
      scores: const {},
      scoreDetail: const {},
      pendingCapture: null,
      lastAction: null,
    );
  }

  /// Kart oynar. Yakalama olursa masa hemen toplanmaz; [PendingCapture]
  /// dolar, çağıran taraf kısa bir gecikmeden sonra [collectPile] çağırır
  /// (oynanan kart masada görünsün diye).
  static PistiGameState? playCard({
    required PistiGameState state,
    required String playerId,
    required PistiCard card,
  }) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (state.pendingCapture != null) return null;

    final hand = List<PistiCard>.from(state.hands[playerId] ?? const []);
    final idx = hand.indexWhere((c) => c.id == card.id);
    if (idx == -1) return null;
    hand.removeAt(idx);

    final hands = {
      for (final e in state.hands.entries) e.key: List<PistiCard>.from(e.value),
    };
    hands[playerId] = hand;

    final pileBefore = List<PistiCard>.from(state.pile);
    final top = pileBefore.isNotEmpty ? pileBefore.last : null;

    var captured = false;
    var isPisti = false;
    if (top != null && top.rank == card.rank) {
      captured = true;
      isPisti = pileBefore.length == 1;
    } else if (card.isJack) {
      captured = pileBefore.isNotEmpty;
    }

    final pile = [...pileBefore, card];
    final lastAction =
        PistiLastAction(player: playerId, card: card, captured: captured, isPisti: isPisti);

    if (captured) {
      final allEmpty = state.players.every((p) => (hands[p]?.length ?? 0) == 0);
      final endsGame = allEmpty && state.drawPile.isEmpty;
      return state.copyWith(
        hands: hands,
        pile: pile,
        lastAction: lastAction,
        pendingCapture: PendingCapture(by: playerId, isPisti: isPisti, endsGame: endsGame),
      );
    }

    // Yakalama yok: sıra ilerler; gerekiyorsa yeni el dağıtılır / oyun biter.
    return _advanceAfterMove(
      state: state,
      hands: hands,
      pile: pile,
      capturerId: null,
      curPlayerId: playerId,
      lastAction: lastAction,
    );
  }

  /// Faz B: pendingCapture'ı sonlandırır — masadaki kartları yakalayan
  /// oyuncuya toplar, sırayı ilerletir, gerekiyorsa yeni el dağıtır / oyunu
  /// bitirir.
  static PistiGameState? collectPile({required PistiGameState state}) {
    final pending = state.pendingCapture;
    if (pending == null) return null;
    final by = pending.by;

    final won = {
      for (final e in state.won.entries) e.key: List<PistiCard>.from(e.value),
    };
    won[by] = [...(won[by] ?? []), ...state.pile];
    final pistiCount = Map<String, int>.from(state.pistiCount);
    if (pending.isPisti) pistiCount[by] = (pistiCount[by] ?? 0) + 1;

    final hands = {
      for (final e in state.hands.entries) e.key: List<PistiCard>.from(e.value),
    };

    return _advanceAfterMove(
      state: state,
      hands: hands,
      pile: const [],
      capturerId: by,
      curPlayerId: by,
      wonOverride: won,
      pistiCountOverride: pistiCount,
    );
  }

  static PistiGameState _advanceAfterMove({
    required PistiGameState state,
    required Map<String, List<PistiCard>> hands,
    required List<PistiCard> pile,
    required String? capturerId,
    required String curPlayerId,
    Map<String, List<PistiCard>>? wonOverride,
    Map<String, int>? pistiCountOverride,
    PistiLastAction? lastAction,
  }) {
    final players = state.players;
    final won = wonOverride ??
        {for (final e in state.won.entries) e.key: List<PistiCard>.from(e.value)};
    final pistiCount = pistiCountOverride ?? Map<String, int>.from(state.pistiCount);
    final drawPile = List<PistiCard>.from(state.drawPile);
    var finalPile = pile;
    final lastCapturer = capturerId ?? state.lastCapturer;
    var status = state.status;
    String? winner;
    var winners = <String>[];
    var scores = <String, int>{};
    var scoreDetail = <String, PistiScoreDetail>{};

    final allHandsEmpty = players.every((p) => (hands[p]?.length ?? 0) == 0);
    if (allHandsEmpty) {
      if (drawPile.isNotEmpty) {
        PistiDeckService.dealRound(hands, players, drawPile);
      } else {
        if (finalPile.isNotEmpty && lastCapturer != null) {
          won[lastCapturer] = [...(won[lastCapturer] ?? []), ...finalPile];
          finalPile = const [];
        }
        final result = PistiDeckService.scoreGame(players, won, pistiCount);
        scores = result.scores;
        scoreDetail = result.detail;
        winners = result.winners;
        winner = winners.length == 1 ? winners.first : null;
        status = 'finished';
      }
    }

    final curIdx = players.indexOf(curPlayerId);
    final nextTurn = status == 'finished'
        ? state.currentTurn
        : (_nextPlayerWithCards(players, hands, curIdx) ?? state.currentTurn);

    return state.copyWith(
      hands: hands,
      pile: finalPile,
      drawPile: drawPile,
      won: won,
      pistiCount: pistiCount,
      lastCapturer: lastCapturer,
      currentTurn: nextTurn,
      status: status,
      clearWinner: winner == null,
      winner: winner,
      winners: winners,
      scores: scores,
      scoreDetail: scoreDetail,
      clearPendingCapture: true,
      lastAction: lastAction,
    );
  }

  static String? _nextPlayerWithCards(
    List<String> players,
    Map<String, List<PistiCard>> hands,
    int fromIdx,
  ) {
    final n = players.length;
    for (var step = 1; step <= n; step++) {
      final idx = _nextIndex(fromIdx, n, step);
      if ((hands[players[idx]]?.length ?? 0) > 0) return players[idx];
    }
    return null;
  }

  /// Oyuncu odadan/oyundan ayrılır. Yeterli oyuncu kalmazsa kalanlar
  /// yakaladıkları kartlarla kazanır; sırası gelen kişi çıktıysa sıra elinde
  /// kartı olan bir sonraki oyuncuya geçer.
  static PistiGameState leavePlayer({required PistiGameState state, required String playerId}) {
    final players = state.players.where((p) => p != playerId).toList();
    final names = Map<String, String>.from(state.playerNames)..remove(playerId);
    final hands = {
      for (final e in state.hands.entries)
        if (e.key != playerId) e.key: e.value,
    };

    if (state.status != 'playing') {
      return state.copyWith(players: players, playerNames: names, hands: hands);
    }
    if (players.length < minPlayers) {
      final result = PistiDeckService.scoreGame(players, state.won, state.pistiCount);
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        status: 'finished',
        scores: result.scores,
        scoreDetail: result.detail,
        winners: result.winners,
        clearWinner: result.winners.length != 1,
        winner: result.winners.length == 1 ? result.winners.first : null,
      );
    }
    if (state.currentTurn == playerId) {
      final oldIdx = state.players.indexOf(playerId);
      String? afterPlayer;
      for (var step = 1; step <= state.players.length; step++) {
        final candidate = state.players[_nextIndex(oldIdx, state.players.length, step)];
        if (candidate == playerId) continue;
        if ((hands[candidate]?.length ?? 0) > 0) {
          afterPlayer = candidate;
          break;
        }
      }
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        currentTurn: afterPlayer ?? players.first,
      );
    }
    return state.copyWith(players: players, playerNames: names, hands: hands);
  }
}
