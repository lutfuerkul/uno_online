import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/local_uno_state.dart';
import '../models/uno_card.dart';
import '../services/deck_service.dart';
import '../services/uno_bot_service.dart';

/// "Bilgisayara Karşı Oyna" modunu yöneten yerel (Firestore'suz) UNO motoru.
/// Tüm kurallar cihaz içinde çalışır; internet ya da Firebase gerekmez.
class LocalUnoProvider extends ChangeNotifier {
  static const String humanId = 'you';
  static const int _startingHandSize = 7;
  static const Duration _botMoveDelay = Duration(milliseconds: 700);

  LocalUnoState? state;

  int _session = 0;
  bool _botLoopRunning = false;

  bool get isMyTurn => state?.currentTurn == humanId;
  List<UnoCard> get myHand => state?.hands[humanId] ?? const [];
  bool get iWon => state?.winner == humanId;

  /// İnsan oyuncu hariç, oturuş sırasına göre diğer oyuncular (botlar).
  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

  String opponentName(String id) => state?.playerNames[id] ?? id;
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;

  bool canPlay(UnoCard card) {
    final s = state;
    final top = s?.topCard;
    if (s == null || top == null || !isMyTurn) return false;
    return DeckService.canPlay(card, top, s.currentColor);
  }

  void startGame({required String playerName, required int totalPlayers}) {
    _session++;
    final session = _session;

    final players = ['you', for (var i = 1; i < totalPlayers; i++) 'bot$i'];
    final names = <String, String>{
      'you': playerName.isEmpty ? 'Sen' : playerName,
      for (var i = 1; i < totalPlayers; i++) 'bot$i': '🤖 Oyuncu $i',
    };

    final deck = DeckService.buildDeck()..shuffle();
    final hands = <String, List<UnoCard>>{
      for (final p in players)
        p: [for (var i = 0; i < _startingHandSize; i++) deck.removeLast()],
    };

    var first = deck.removeLast();
    while (first.isWild || first.type != CardType.number) {
      deck.insert(0, first);
      first = deck.removeLast();
    }

    state = LocalUnoState(
      players: players,
      playerNames: names,
      hands: hands,
      drawPile: deck,
      discardPile: [first],
      currentColor: first.color,
      currentTurn: players[Random().nextInt(players.length)],
      direction: 1,
      status: 'playing',
      winner: null,
    );
    notifyListeners();
    _scheduleBotLoop(session);
  }

  Future<void> playCard(UnoCard card, {CardColor? chosenColor}) async {
    final s = state;
    if (s == null || s.status != 'playing' || s.currentTurn != humanId) return;
    _applyMove(humanId, card, chosenColor);
    _scheduleBotLoop(_session);
  }

  Future<void> drawCard() async {
    final s = state;
    if (s == null || s.status != 'playing' || s.currentTurn != humanId) return;
    _applyDraw(humanId);
    _scheduleBotLoop(_session);
  }

  /// Oyundan çıkıp giriş ekranına döner; bekleyen bot hamlelerini iptal eder.
  void leaveGame() {
    _session++;
    state = null;
    notifyListeners();
  }

  // --- Dahili oyun motoru ---

  void _applyMove(String playerId, UnoCard card, CardColor? chosenColor) {
    final s = state!;
    final hand = List<UnoCard>.from(s.hands[playerId]!);
    final idx = hand.indexWhere((c) => c.id == card.id);
    if (idx == -1) return;
    hand.removeAt(idx);

    final discard = List<UnoCard>.from(s.discardPile)..add(card);
    final hands = {
      for (final e in s.hands.entries) e.key: List<UnoCard>.from(e.value),
    };
    hands[playerId] = hand;
    final draw = List<UnoCard>.from(s.drawPile);

    final newColor =
        card.isWild ? (chosenColor ?? UnoBotService.pickColor(hand)) : card.color;
    final n = s.players.length;
    final curIdx = s.players.indexOf(playerId);
    var direction = s.direction;
    int nextIdx;

    switch (card.type) {
      case CardType.skip:
        nextIdx = _step(curIdx, direction, n, 2);
        break;
      case CardType.reverse:
        if (n == 2) {
          // 2 kişilik oyunda ters kart, tur atlatma gibi davranır.
          nextIdx = _step(curIdx, direction, n, 2);
        } else {
          direction = -direction;
          nextIdx = _step(curIdx, direction, n, 1);
        }
        break;
      case CardType.drawTwo:
        final target = s.players[_step(curIdx, direction, n, 1)];
        _drawInto(hands, target, draw, discard, 2);
        nextIdx = _step(curIdx, direction, n, 2);
        break;
      case CardType.wildDrawFour:
        final target = s.players[_step(curIdx, direction, n, 1)];
        _drawInto(hands, target, draw, discard, 4);
        nextIdx = _step(curIdx, direction, n, 2);
        break;
      case CardType.number:
      case CardType.wild:
        nextIdx = _step(curIdx, direction, n, 1);
        break;
    }

    final finished = hand.isEmpty;
    state = s.copyWith(
      hands: hands,
      drawPile: draw,
      discardPile: discard,
      currentColor: newColor,
      currentTurn: finished ? playerId : s.players[nextIdx],
      direction: direction,
      status: finished ? 'finished' : 'playing',
      winner: finished ? playerId : null,
    );
    notifyListeners();
  }

  void _applyDraw(String playerId) {
    final s = state!;
    final hands = {
      for (final e in s.hands.entries) e.key: List<UnoCard>.from(e.value),
    };
    final draw = List<UnoCard>.from(s.drawPile);
    final discard = List<UnoCard>.from(s.discardPile);
    _drawInto(hands, playerId, draw, discard, 1);

    final n = s.players.length;
    final curIdx = s.players.indexOf(playerId);
    final nextIdx = _step(curIdx, s.direction, n, 1);

    state = s.copyWith(
      hands: hands,
      drawPile: draw,
      discardPile: discard,
      currentTurn: s.players[nextIdx],
    );
    notifyListeners();
  }

  /// [player] eline [count] kart çeker. Çekme destesi biterse atılan deste
  /// (en üstteki hariç) yeniden karılır. Hiç kart kalmasa da sıra ilerler ki
  /// oyun kilitlenmesin.
  void _drawInto(
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

  void _reshuffle(List<UnoCard> draw, List<UnoCard> discard) {
    if (discard.length <= 1) return;
    final top = discard.removeLast();
    draw.addAll(discard);
    draw.shuffle();
    discard
      ..clear()
      ..add(top);
  }

  int _step(int idx, int direction, int n, int steps) =>
      ((idx + direction * steps) % n + n) % n;

  /// Sıradaki oyuncu(lar) bot olduğu sürece kısa gecikmelerle hamlelerini
  /// oynatır; insanın sırası gelince ya da oyun bitince durur.
  Future<void> _scheduleBotLoop(int session) async {
    if (_botLoopRunning) return;
    _botLoopRunning = true;
    try {
      while (true) {
        final s = state;
        if (s == null || s.status != 'playing' || session != _session) break;
        if (s.currentTurn == humanId) break;
        await Future.delayed(_botMoveDelay);
        if (session != _session) break;
        final s2 = state;
        if (s2 == null || s2.status != 'playing' || s2.currentTurn == humanId) {
          break;
        }
        _runBotMove(s2.currentTurn);
      }
    } finally {
      _botLoopRunning = false;
    }
  }

  void _runBotMove(String botId) {
    final s = state!;
    final hand = s.hands[botId] ?? const [];
    final playableCards = UnoBotService.playable(hand, s);
    if (playableCards.isEmpty) {
      _applyDraw(botId);
      return;
    }
    final card = UnoBotService.pickCard(playableCards, s, botId);
    final remaining = hand.where((c) => c.id != card.id).toList();
    final chosenColor = card.isWild ? UnoBotService.pickColor(remaining) : null;
    _applyMove(botId, card, chosenColor);
  }
}
