import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import '../services/pisti_bot_service.dart';
import '../services/pisti_deck_service.dart';

/// "Bilgisayara Karşı Oyna" modunu yöneten yerel (Firestore'suz) Pişti
/// motoru. İnternet ya da Firebase gerekmez.
class PistiLocalProvider extends ChangeNotifier {
  static const String humanId = 'you';
  static const Duration _collectDelay = Duration(milliseconds: 1100);
  static const Duration _botMoveDelay = Duration(milliseconds: 900);

  PistiGameState? state;

  int _session = 0;
  bool _botLoopRunning = false;

  bool get isMyTurn =>
      state?.currentTurn == humanId && state?.pendingCapture == null;
  List<PistiCard> get myHand => state?.hands[humanId] ?? const [];
  int wonCount(String id) => state?.won[id]?.length ?? 0;

  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

  String opponentName(String id) => state?.playerNames[id] ?? id;
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;

  void startGame({required String playerName, required int totalPlayers}) {
    _session++;
    final session = _session;

    final players = ['you', for (var i = 1; i < totalPlayers; i++) 'bot$i'];
    final names = <String, String>{
      'you': playerName.isEmpty ? 'Sen' : playerName,
      for (var i = 1; i < totalPlayers; i++) 'bot$i': '🤖 Oyuncu $i',
    };

    final numDecks = totalPlayers > 2 ? 2 : 1;
    final tableSize = totalPlayers == 3 ? 5 : 4;
    final deck = PistiDeckService.buildDeck(numDecks: numDecks)..shuffle();
    final hands = PistiDeckService.dealHands(deck, players);
    final pile = PistiDeckService.dealTable(deck, tableSize);

    state = PistiGameState(
      players: players,
      playerNames: names,
      hands: hands,
      pile: pile,
      drawPile: deck,
      won: {for (final p in players) p: <PistiCard>[]},
      pistiCount: {for (final p in players) p: 0},
      lastCapturer: null,
      currentTurn: players[Random().nextInt(players.length)],
      status: 'playing',
      winner: null,
      winners: const [],
      scores: const {},
      scoreDetail: const {},
      pendingCapture: null,
    );
    notifyListeners();
    _scheduleBotLoop(session);
  }

  /// Oyundan çıkıp giriş ekranına döner; bekleyen bot hamlelerini iptal eder.
  void leaveGame() {
    _session++;
    state = null;
    notifyListeners();
  }

  Future<void> playCard(PistiCard card) async {
    final s = state;
    if (s == null || s.status != 'playing' || s.currentTurn != humanId) return;
    if (s.pendingCapture != null) return;
    _applyPlay(humanId, card);
    if (state?.pendingCapture != null) {
      await _resolveCapture(_session);
    }
    _scheduleBotLoop(_session);
  }

  // --- Dahili oyun motoru ---

  void _applyPlay(String playerId, PistiCard card) {
    final s = state!;
    final hand = List<PistiCard>.from(s.hands[playerId]!);
    final idx = hand.indexWhere((c) => c.id == card.id);
    if (idx == -1) return;
    hand.removeAt(idx);

    final hands = {
      for (final e in s.hands.entries) e.key: List<PistiCard>.from(e.value),
    };
    hands[playerId] = hand;

    final pileBefore = List<PistiCard>.from(s.pile);
    final top = pileBefore.isNotEmpty ? pileBefore.last : null;

    var captured = false;
    var isPisti = false;
    if (card.isJack) {
      captured = pileBefore.isNotEmpty;
    } else if (top != null && top.rank == card.rank) {
      captured = true;
      isPisti = pileBefore.length == 1;
    }

    final pile = [...pileBefore, card];

    if (captured) {
      final allEmpty = s.players.every((p) => (hands[p]?.length ?? 0) == 0);
      final endsGame = allEmpty && s.drawPile.isEmpty;
      state = s.copyWith(
        hands: hands,
        pile: pile,
        pendingCapture:
            PendingCapture(by: playerId, isPisti: isPisti, endsGame: endsGame),
      );
      notifyListeners();
      return;
    }

    // Yakalama yok: sıra ilerler; gerekiyorsa yeni el dağıtılır / oyun biter.
    _advanceAfterMove(
      hands: hands,
      pile: pile,
      capturerId: null,
      curPlayerId: playerId,
    );
  }

  Future<void> _resolveCapture(int session) async {
    await Future.delayed(_collectDelay);
    if (session != _session) return;
    final s = state;
    if (s == null || s.pendingCapture == null) return;
    final by = s.pendingCapture!.by;
    final isPisti = s.pendingCapture!.isPisti;

    final won = {
      for (final e in s.won.entries) e.key: List<PistiCard>.from(e.value),
    };
    won[by] = [...(won[by] ?? []), ...s.pile];
    final pistiCount = Map<String, int>.from(s.pistiCount);
    if (isPisti) pistiCount[by] = (pistiCount[by] ?? 0) + 1;

    final hands = {
      for (final e in s.hands.entries) e.key: List<PistiCard>.from(e.value),
    };

    _advanceAfterMove(
      hands: hands,
      pile: const [],
      capturerId: by,
      curPlayerId: by,
      wonOverride: won,
      pistiCountOverride: pistiCount,
    );
  }

  /// Yakalama sonrası ya da yakalamasız hamle sonrası ortak akış: eller
  /// biterse yeni el dağıtır ya da oyunu bitirir, sırayı ilerletir.
  void _advanceAfterMove({
    required Map<String, List<PistiCard>> hands,
    required List<PistiCard> pile,
    required String? capturerId,
    required String curPlayerId,
    Map<String, List<PistiCard>>? wonOverride,
    Map<String, int>? pistiCountOverride,
  }) {
    final s = state!;
    final players = s.players;
    final won = wonOverride ??
        {for (final e in s.won.entries) e.key: List<PistiCard>.from(e.value)};
    final pistiCount = pistiCountOverride ?? Map<String, int>.from(s.pistiCount);
    final drawPile = List<PistiCard>.from(s.drawPile);
    var finalPile = pile;
    final lastCapturer = capturerId ?? s.lastCapturer;
    var status = s.status;
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
        ? s.currentTurn
        : (_nextPlayerWithCards(players, hands, curIdx) ?? s.currentTurn);

    state = s.copyWith(
      hands: hands,
      pile: finalPile,
      drawPile: drawPile,
      won: won,
      pistiCount: pistiCount,
      lastCapturer: lastCapturer,
      currentTurn: nextTurn,
      status: status,
      winner: winner,
      winners: winners,
      scores: scores,
      scoreDetail: scoreDetail,
      clearPendingCapture: true,
    );
    notifyListeners();
  }

  String? _nextPlayerWithCards(
    List<String> players,
    Map<String, List<PistiCard>> hands,
    int fromIdx,
  ) {
    final n = players.length;
    for (var step = 1; step <= n; step++) {
      final idx = ((fromIdx + step) % n + n) % n;
      if ((hands[players[idx]]?.length ?? 0) > 0) return players[idx];
    }
    return null;
  }

  /// Sıradaki oyuncu(lar) bot olduğu sürece kısa gecikmelerle hamlelerini
  /// oynatır; insanın sırası gelince ya da oyun bitince durur.
  Future<void> _scheduleBotLoop(int session) async {
    if (_botLoopRunning) return;
    _botLoopRunning = true;
    try {
      while (true) {
        final s = state;
        if (s == null || s.status != 'playing' || session != _session) break;
        if (s.pendingCapture != null) break; // masa toplanana kadar bekle
        if (s.currentTurn == humanId) break;
        await Future.delayed(_botMoveDelay);
        if (session != _session) break;
        final s2 = state;
        if (s2 == null || s2.status != 'playing' || s2.currentTurn == humanId) {
          break;
        }
        final botId = s2.currentTurn;
        final card = PistiBotService.choose(s2, botId);
        _applyPlay(botId, card);
        if (state?.pendingCapture != null) {
          await _resolveCapture(session);
        }
      }
    } finally {
      _botLoopRunning = false;
    }
  }
}
