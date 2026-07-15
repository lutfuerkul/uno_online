import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/pisti_board_controller.dart';
import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import '../services/pisti_engine.dart';
import '../services/pisti_game_service.dart';

/// Uygulama genelinde (online) Pişti oyun durumunu tutar ve UI ile
/// [PistiGameService] arasında köprü kurar.
class PistiOnlineProvider extends ChangeNotifier implements PistiBoardController {
  static const int maxNameLength = 8;
  static const int maxPlayers = PistiEngine.maxPlayers;

  final PistiGameService _service = PistiGameService();

  final String playerId = const Uuid().v4();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  PistiGameState? state;
  String? error;

  StreamSubscription<PistiGameState?>? _sub;

  @override
  bool get isMyTurn => state?.currentTurn == playerId && state?.pendingCapture == null;
  @override
  List<PistiCard> get myHand => state?.hands[playerId] ?? const [];

  bool get isHost => state != null && state!.players.isNotEmpty && state!.players.first == playerId;

  @override
  List<String> get opponents {
    final s = state;
    if (s == null) return const [];
    final players = s.players;
    final myIdx = players.indexOf(playerId);
    if (myIdx == -1) return players.where((p) => p != playerId).toList();
    final n = players.length;
    return [for (var i = 1; i < n; i++) players[(myIdx + i) % n]];
  }

  @override
  String opponentName(String id) => state?.playerNames[id] ?? id;
  @override
  int opponentCardCount(String id) => state?.hands[id]?.length ?? 0;
  @override
  int wonCount(String id) => state?.won[id]?.length ?? 0;
  @override
  int pistiCountFor(String id) => state?.pistiCount[id] ?? 0;

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

  /// Yalnızca kurucu, oyuncu sayısı 2, 3 ya da 4 iken çağırabilir.
  Future<void> startGame() async {
    final id = gameId;
    if (id == null) return;
    await _service.startGame(gameId: id, playerId: playerId);
  }

  @override
  Future<void> playCard(PistiCard card) async {
    final id = gameId;
    if (id == null) return;
    await _service.playCard(gameId: id, playerId: playerId, cardId: card.id);
    // Yakalama olduysa, oynanan kart masada kısa süre görünsün diye bir
    // gecikmeden sonra masayı topla (bkz. PistiLocalProvider ile aynı desen).
    if (state?.pendingCapture != null) {
      final session = gameId;
      final endsGame = state!.pendingCapture!.endsGame;
      final delayMs = endsGame ? 2000 : 1200;
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (gameId == session) _service.collectPile(id);
      });
    }
  }

  Future<void> rematch() async {
    final id = gameId;
    if (id == null) return;
    await _service.rematch(id);
  }

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
    return trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed;
  }

  String _friendlyError(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
