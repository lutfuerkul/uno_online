import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import '../services/deck_service.dart';
import '../services/game_service.dart';

/// Uygulama genelinde oyun durumunu tutar ve UI ile [GameService] arasında
/// köprü kurar.
class GameProvider extends ChangeNotifier {
  static const int maxNameLength = 12;
  static const int maxOppCardVisual = 4;

  final GameService _service = GameService();

  /// Bu cihaz/oyuncu için oturum boyu geçerli benzersiz kimlik.
  final String playerId = const Uuid().v4();

  String? _playerName;
  String? gameId;
  GameState? state;
  String? error;

  StreamSubscription<GameState?>? _sub;

  bool get isMyTurn => state?.currentTurn == playerId;

  List<UnoCard> get myHand => state?.hands[playerId] ?? const [];

  String get opponentId =>
      state?.players.firstWhere((p) => p != playerId, orElse: () => '') ?? '';

  int get opponentCardCount => state?.hands[opponentId]?.length ?? 0;

  String get opponentName => state?.playerNames[opponentId] ?? 'Rakip';

  bool get iWon => state?.winner == playerId;

  /// Verilen kart şu an oynanabilir mi?
  bool canPlay(UnoCard card) {
    final s = state;
    final top = s?.topCard;
    if (s == null || top == null) return false;
    if (!isMyTurn) return false;
    return DeckService.canPlay(card, top, s.currentColor);
  }

  Future<void> createGame(String name) async {
    error = null;
    _playerName = _normalizeName(name);
    try {
      final id = await _service.createGame(playerId, _playerName!);
      _subscribe(id);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> joinGame(String code, String name) async {
    error = null;
    _playerName = _normalizeName(name);
    final id = code.toUpperCase().trim();
    try {
      await _service.joinGame(id, playerId, _playerName!);
      _subscribe(id);
    } catch (e) {
      error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> playCard(UnoCard card, {CardColor? chosenColor}) async {
    final id = gameId;
    if (id == null) return;
    await _service.playCard(
      gameId: id,
      playerId: playerId,
      cardId: card.id,
      chosenColor: chosenColor,
    );
  }

  Future<void> drawCard() async {
    final id = gameId;
    if (id == null) return;
    await _service.drawCard(gameId: id, playerId: playerId);
  }

  /// Odadan ayrılıp giriş ekranına döner.
  void leaveGame() {
    _sub?.cancel();
    _sub = null;
    gameId = null;
    state = null;
    error = null;
    notifyListeners();
  }

  void _subscribe(String id) {
    gameId = id;
    _sub?.cancel();
    _sub = _service.watchGame(id).listen((s) {
      state = s;
      notifyListeners();
    });
    notifyListeners();
  }

  String _normalizeName(String name) {
    final trimmed = name.trim();
    return trimmed.length > maxNameLength
        ? trimmed.substring(0, maxNameLength)
        : trimmed;
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    return msg.replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
