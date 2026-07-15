import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/game_state.dart';
import '../models/uno_board_controller.dart';
import '../models/uno_card.dart';
import '../services/game_service.dart';
import '../services/uno_engine.dart';

/// Uygulama genelinde (online) oyun durumunu tutar ve UI ile [GameService]
/// arasında köprü kurar.
class GameProvider extends ChangeNotifier implements UnoBoardController {
  static const int maxNameLength = 8;
  static const int maxOppCardVisual = 4;
  static const int maxPlayers = UnoEngine.maxPlayers;

  final GameService _service = GameService();

  /// Bu cihaz/oyuncu için oturum boyu geçerli benzersiz kimlik.
  final String playerId = const Uuid().v4();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  GameState? state;
  String? error;

  StreamSubscription<GameState?>? _sub;

  @override
  bool get isMyTurn => state?.currentTurn == playerId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;
  @override
  CardColor? get reverseColor => state?.reverseColor;

  bool get isHost => state != null && state!.players.isNotEmpty && state!.players.first == playerId;

  @override
  List<UnoCard> get myHand => state?.hands[playerId] ?? const [];

  /// Sıra yönünde (soldan sağa) diğer oyuncular.
  @override
  List<String> get opponents {
    final s = state;
    if (s == null) return const [];
    final players = s.players;
    final myIdx = players.indexOf(playerId);
    if (myIdx == -1) return players.where((p) => p != playerId).toList();
    final dir = s.direction;
    final n = players.length;
    return [
      for (var i = 1; i < n; i++) players[((myIdx + dir * i) % n + n) % n],
    ];
  }

  @override
  String opponentName(String id) => state?.playerNames[id] ?? id;
  @override
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;
  @override
  int blockedCount(String id) => state?.blockedPlayers.where((p) => p == id).length ?? 0;

  @override
  bool get iWon => state?.winner == playerId;

  /// Verilen kart şu an oynanabilir mi?
  @override
  bool canPlay(UnoCard card) {
    final s = state;
    if (s == null || !isMyTurn) return false;
    return UnoEngine.isPlayable(card, s);
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

  /// Yalnızca kurucu, en az 2 oyuncu varken çağırabilir.
  Future<void> startGame() async {
    final id = gameId;
    if (id == null) return;
    await _service.startGame(gameId: id, playerId: playerId);
  }

  @override
  Future<void> playCard(UnoCard card, {CardColor? chosenColor, String? targetId}) async {
    final id = gameId;
    if (id == null) return;
    await _service.playCard(
      gameId: id,
      playerId: playerId,
      cardId: card.id,
      chosenColor: chosenColor,
      targetId: targetId,
    );
  }

  @override
  Future<void> drawCard() async {
    final id = gameId;
    if (id == null) return;
    await _service.drawCard(gameId: id, playerId: playerId);
  }

  @override
  Future<void> pass() async {
    final id = gameId;
    if (id == null) return;
    await _service.pass(gameId: id, playerId: playerId);
  }

  Future<void> rematch() async {
    final id = gameId;
    if (id == null) return;
    await _service.rematch(id);
  }

  /// Odadan ayrılıp giriş ekranına döner.
  @override
  Future<void> leaveGame() async {
    final id = gameId;
    if (id != null) {
      await _service.leaveRoom(gameId: id, playerId: playerId);
    }
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
