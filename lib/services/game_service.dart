import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import 'deck_service.dart';

/// Firestore ile tüm oyun iletişimini yürütür: oda kurma, katılma, kart
/// oynama, kart çekme ve oyunu canlı dinleme.
///
/// Yarış durumlarını (aynı anda yazma) önlemek için hamleler `runTransaction`
/// içinde yapılır.
class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

  /// Yeni oda kurar ve oda kodunu döndürür. Oyun 2. oyuncu katılınca başlar.
  Future<String> createGame(String playerId, String name) async {
    final code = _generateCode();
    await _games.doc(code).set({
      'status': 'waiting',
      'players': [playerId],
      'playerNames': {playerId: name},
      'hands': <String, dynamic>{},
      'drawPile': <dynamic>[],
      'discardPile': <dynamic>[],
      'currentColor': CardColor.red.name,
      'currentTurn': '',
      'winner': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Var olan odaya katılır. İkinci oyuncu katılınca deste karılır, kartlar
  /// dağıtılır ve oyun başlar.
  Future<void> joinGame(String gameId, String playerId, String name) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Oyun bulunamadı: $gameId');
      }
      final data = snap.data()!;
      final players = List<String>.from(data['players'] as List? ?? []);
      final names = Map<String, dynamic>.from(data['playerNames'] as Map? ?? {});

      // Zaten bu odadaysa bir şey yapma (yeniden bağlanma).
      if (players.contains(playerId)) return;
      if (players.length >= 2) {
        throw Exception('Bu oda dolu.');
      }

      players.add(playerId);
      names[playerId] = name;

      // Oyunu başlat: deste kur, karıştır, 7'şer kart dağıt.
      final deck = DeckService.buildDeck()..shuffle();
      final hands = <String, List<UnoCard>>{};
      for (final p in players) {
        hands[p] = [for (var i = 0; i < 7; i++) deck.removeLast()];
      }

      // İlk atılan kart sayı kartı olsun (basitlik için joker/aksiyon olmasın).
      var first = deck.removeLast();
      while (first.isWild || first.type != CardType.number) {
        deck.insert(0, first);
        first = deck.removeLast();
      }

      tx.update(ref, {
        'players': players,
        'playerNames': names,
        'hands': _encodeHands(hands),
        'drawPile': _encodeCards(deck),
        'discardPile': _encodeCards([first]),
        'currentColor': first.color.name,
        'currentTurn': players[0],
        'status': 'playing',
      });
    });
  }

  /// Oyun belgesini canlı dinler.
  Stream<GameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) => snap.exists ? GameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  /// Sırası gelen oyuncu bir kart oynar. Joker ise [chosenColor] zorunludur.
  Future<void> playCard({
    required String gameId,
    required String playerId,
    required String cardId,
    CardColor? chosenColor,
  }) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = GameState.fromMap(gameId, snap.data()!);

      if (game.status != 'playing') return;
      if (game.currentTurn != playerId) return;

      final hand = List<UnoCard>.from(game.hands[playerId] ?? []);
      final idx = hand.indexWhere((c) => c.id == cardId);
      if (idx == -1) return;
      final card = hand[idx];

      final top = game.topCard;
      if (top == null) return;
      if (!DeckService.canPlay(card, top, game.currentColor)) return;
      if (card.isWild && chosenColor == null) return;

      hand.removeAt(idx);
      final discard = List<UnoCard>.from(game.discardPile)..add(card);
      final draw = List<UnoCard>.from(game.drawPile);
      final hands = {
        for (final entry in game.hands.entries)
          entry.key: List<UnoCard>.from(entry.value),
      };
      hands[playerId] = hand;

      final newColor = card.isWild ? chosenColor! : card.color;
      final opponent = game.players.firstWhere((p) => p != playerId);

      // 2 kişilik kurallar: skip/reverse/+2/+4 sonrası sıra yine sende kalır.
      String nextTurn;
      switch (card.type) {
        case CardType.skip:
        case CardType.reverse:
          nextTurn = playerId;
          break;
        case CardType.drawTwo:
          _drawInto(hands, opponent, draw, discard, 2);
          nextTurn = playerId;
          break;
        case CardType.wildDrawFour:
          _drawInto(hands, opponent, draw, discard, 4);
          nextTurn = playerId;
          break;
        case CardType.number:
        case CardType.wild:
          nextTurn = opponent;
          break;
      }

      var status = game.status;
      String? winner = game.winner;
      if (hand.isEmpty) {
        status = 'finished';
        winner = playerId;
      }

      tx.update(ref, {
        'hands': _encodeHands(hands),
        'drawPile': _encodeCards(draw),
        'discardPile': _encodeCards(discard),
        'currentColor': newColor.name,
        'currentTurn': nextTurn,
        'status': status,
        'winner': winner,
      });
    });
  }

  /// Sırası gelen oyuncu desteden bir kart çeker; ardından sıra rakibe geçer.
  Future<void> drawCard({
    required String gameId,
    required String playerId,
  }) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = GameState.fromMap(gameId, snap.data()!);

      if (game.status != 'playing') return;
      if (game.currentTurn != playerId) return;

      final draw = List<UnoCard>.from(game.drawPile);
      final discard = List<UnoCard>.from(game.discardPile);
      final hands = {
        for (final entry in game.hands.entries)
          entry.key: List<UnoCard>.from(entry.value),
      };

      _drawInto(hands, playerId, draw, discard, 1);
      final opponent = game.players.firstWhere((p) => p != playerId);

      tx.update(ref, {
        'hands': _encodeHands(hands),
        'drawPile': _encodeCards(draw),
        'discardPile': _encodeCards(discard),
        'currentTurn': opponent,
      });
    });
  }

  // --- Yardımcılar ---

  /// [player] eline [count] kart çeker. Çekme destesi biterse atılan deste
  /// (en üstteki hariç) yeniden karılır.
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
        if (draw.isEmpty) break; // çekilecek kart kalmadı
      }
      hand.add(draw.removeLast());
    }
    hands[player] = hand;
  }

  /// Atılan desteyi (en üstteki kart hariç) çekme destesine karıştırır.
  void _reshuffle(List<UnoCard> draw, List<UnoCard> discard) {
    if (discard.length <= 1) return;
    final top = discard.removeLast();
    draw.addAll(discard);
    draw.shuffle();
    discard
      ..clear()
      ..add(top);
  }

  List<Map<String, dynamic>> _encodeCards(List<UnoCard> cards) =>
      cards.map((c) => c.toMap()).toList();

  Map<String, dynamic> _encodeHands(Map<String, List<UnoCard>> hands) =>
      hands.map((k, v) => MapEntry(k, _encodeCards(v)));

  /// Karışması zor karakterlerle 5 haneli oda kodu üretir.
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join();
  }
}
