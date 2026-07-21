import 'dart:math';

import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import 'okey_deck_service.dart';
import 'okey_meld_solver.dart';

/// Okey'in tur/kural motoru. Firestore'a mı yoksa yerel belleğe mi yazıldığını
/// bilmez; yalnızca bir [OkeyGameState] alıp yeni bir [OkeyGameState] üretir.
class OkeyEngine {
  static const int minPlayers = 2;
  static const int maxPlayers = 4;
  static const allowedPlayerCounts = [2, 3, 4];

  /// El açan (normal) kazanç puanı ve okey atarak bitirme (çifte) puanı.
  static const int winPoints = 2;
  static const int okeyWinPoints = 4;

  /// Yeni bir el dağıtır. İlk hamleyi rastgele bir oyuncu (15 taşla) açar;
  /// o oyuncu turuna çekmeden (hasDrawn = true) başlar, sadece atar.
  static OkeyGameState dealNewGame({
    required String id,
    required List<String> players,
    required Map<String, String> playerNames,
  }) {
    final starterIndex = Random().nextInt(players.length);
    final dealt =
        OkeyDeckService.deal(players: players, starterIndex: starterIndex);

    return OkeyGameState(
      id: id,
      status: 'playing',
      players: players,
      playerNames: playerNames,
      hands: dealt.hands,
      drawPile: dealt.drawPile,
      discards: {for (final p in players) p: <OkeyTile>[]},
      indicator: dealt.indicator,
      currentTurn: players[starterIndex],
      hasDrawn: true, // 15 taşlı açan oyuncu çekmeden atar
      drawnFromDiscardId: null,
      lastAction: null,
      winner: null,
      winners: const [],
      finishedByOkey: false,
      scores: const {},
    );
  }

  static int _idx(List<String> players, String id) => players.indexOf(id);

  static String _prevPlayer(List<String> players, String id) {
    final n = players.length;
    final i = _idx(players, id);
    return players[(i - 1 + n) % n];
  }

  static String _nextPlayer(List<String> players, String id) {
    final n = players.length;
    final i = _idx(players, id);
    return players[(i + 1) % n];
  }

  /// Ortadaki desteden (kapalı yığın) taş çeker.
  static OkeyGameState? drawFromStack({
    required OkeyGameState state,
    required String playerId,
  }) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (state.hasDrawn) return null;
    if (state.drawPile.isEmpty) return null;

    final drawPile = List<OkeyTile>.of(state.drawPile);
    final tile = drawPile.removeLast();
    final hands = _cloneHands(state.hands);
    hands[playerId] = [...hands[playerId]!, tile];

    return state.copyWith(
      hands: hands,
      drawPile: drawPile,
      hasDrawn: true,
      clearDrawnFromDiscard: true,
      lastAction: OkeyLastAction(
        player: playerId,
        type: 'draw',
        fromDiscard: false,
        tile: null,
      ),
    );
  }

  /// Soldaki oyuncunun en üstteki ıskartasını alır.
  static OkeyGameState? drawFromDiscard({
    required OkeyGameState state,
    required String playerId,
  }) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (state.hasDrawn) return null;

    final prev = _prevPlayer(state.players, playerId);
    final prevDiscards = state.discards[prev] ?? const [];
    if (prevDiscards.isEmpty) return null;

    final discards = _cloneHands(state.discards);
    final tile = discards[prev]!.removeLast();
    final hands = _cloneHands(state.hands);
    hands[playerId] = [...hands[playerId]!, tile];

    return state.copyWith(
      hands: hands,
      discards: discards,
      hasDrawn: true,
      drawnFromDiscardId: tile.id,
      lastAction: OkeyLastAction(
        player: playerId,
        type: 'draw',
        fromDiscard: true,
        tile: tile,
      ),
    );
  }

  /// Taş atar. Atıştan sonra elde 14 taş kalır; bunlar geçerli gruplara
  /// bölünüyorsa oyuncu eli açar (kazanır). Aksi halde sıra bir sonrakine
  /// geçer. Deste bittiyse el berabere sonlanır.
  static OkeyGameState? discard({
    required OkeyGameState state,
    required String playerId,
    required OkeyTile tile,
  }) {
    if (state.status != 'playing' || state.currentTurn != playerId) return null;
    if (!state.hasDrawn) return null;
    // Soldan alınan taş aynı turda geri atılamaz.
    if (state.drawnFromDiscardId != null &&
        state.drawnFromDiscardId == tile.id) {
      return null;
    }

    final hand = List<OkeyTile>.of(state.hands[playerId] ?? const []);
    final handIdx = hand.indexWhere((t) => t.id == tile.id);
    if (handIdx == -1) return null;
    final discarded = hand.removeAt(handIdx);

    final hands = _cloneHands(state.hands);
    hands[playerId] = hand;

    final discards = _cloneHands(state.discards);
    discards[playerId] = [...discards[playerId]!, discarded];

    final lastAction = OkeyLastAction(
      player: playerId,
      type: 'discard',
      fromDiscard: false,
      tile: discarded,
    );

    // El açma kontrolü: kalan 14 taş geçerli gruplara bölünüyor mu?
    if (hand.length == 14 &&
        OkeyMeldSolver.isWinningHand(hand, state.isOkey)) {
      final byOkey = state.isOkey(discarded);
      final points = byOkey ? okeyWinPoints : winPoints;
      return state.copyWith(
        status: 'finished',
        hands: hands,
        discards: discards,
        hasDrawn: false,
        clearDrawnFromDiscard: true,
        lastAction: lastAction,
        winner: playerId,
        winners: [playerId],
        finishedByOkey: byOkey,
        scores: {for (final p in state.players) p: p == playerId ? points : 0},
      );
    }

    // Deste bittiyse el berabere sonlanır.
    if (state.drawPile.isEmpty) {
      return state.copyWith(
        status: 'finished',
        hands: hands,
        discards: discards,
        hasDrawn: false,
        clearDrawnFromDiscard: true,
        lastAction: lastAction,
        clearWinner: true,
        winners: const [],
        finishedByOkey: false,
        scores: {for (final p in state.players) p: 0},
      );
    }

    return state.copyWith(
      hands: hands,
      discards: discards,
      currentTurn: _nextPlayer(state.players, playerId),
      hasDrawn: false,
      clearDrawnFromDiscard: true,
      lastAction: lastAction,
    );
  }

  /// Oyuncu odadan/oyundan ayrılır. Yeterli oyuncu kalmazsa el berabere
  /// sonlanır; sırası gelen kişi çıktıysa sıra bir sonrakine geçer.
  static OkeyGameState leavePlayer({
    required OkeyGameState state,
    required String playerId,
  }) {
    final players = state.players.where((p) => p != playerId).toList();
    final names = Map<String, String>.from(state.playerNames)..remove(playerId);
    final hands = {
      for (final e in state.hands.entries)
        if (e.key != playerId) e.key: e.value,
    };
    final discards = {
      for (final e in state.discards.entries)
        if (e.key != playerId) e.key: e.value,
    };

    if (state.status != 'playing') {
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        discards: discards,
      );
    }

    if (players.length < minPlayers) {
      return state.copyWith(
        players: players,
        playerNames: names,
        hands: hands,
        discards: discards,
        status: 'finished',
        clearWinner: players.length != 1,
        winner: players.length == 1 ? players.first : null,
        winners: players.length == 1 ? [players.first] : const [],
        scores: {for (final p in players) p: 0},
      );
    }

    var currentTurn = state.currentTurn;
    var hasDrawn = state.hasDrawn;
    if (currentTurn == playerId) {
      currentTurn = _nextPlayerAmong(state.players, players, playerId);
      hasDrawn = false;
    }

    return state.copyWith(
      players: players,
      playerNames: names,
      hands: hands,
      discards: discards,
      currentTurn: currentTurn,
      hasDrawn: hasDrawn,
      clearDrawnFromDiscard: true,
    );
  }

  static String _nextPlayerAmong(
    List<String> oldOrder,
    List<String> remaining,
    String leaver,
  ) {
    final n = oldOrder.length;
    final i = oldOrder.indexOf(leaver);
    for (var step = 1; step <= n; step++) {
      final candidate = oldOrder[(i + step) % n];
      if (candidate != leaver && remaining.contains(candidate)) {
        return candidate;
      }
    }
    return remaining.first;
  }

  static Map<String, List<OkeyTile>> _cloneHands(
      Map<String, List<OkeyTile>> src) {
    return {for (final e in src.entries) e.key: List<OkeyTile>.of(e.value)};
  }
}
