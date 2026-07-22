import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_engine.dart';
import '../services/okey_game_service.dart';
import '../services/okey_hand_order.dart';
import '../services/okey_meld_solver.dart';

/// Uygulama genelinde (online) Okey oyun durumunu tutar ve UI ile
/// [OkeyGameService] arasında köprü kurar.
class OkeyOnlineProvider extends ChangeNotifier implements OkeyBoardController {
  static const int maxNameLength = 8;
  static const int maxPlayers = OkeyEngine.maxPlayers;

  final OkeyGameService _service = OkeyGameService();
  final String playerId = const Uuid().v4();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  OkeyGameState? state;
  String? error;
  List<String?> _slots = const [];

  StreamSubscription<OkeyGameState?>? _sub;

  @override
  bool get isMyTurn =>
      state?.status == 'playing' && state?.currentTurn == playerId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;

  List<String> get _handIds =>
      (state?.hands[playerId] ?? const []).map((t) => t.id).toList();

  @override
  List<String?> get handSlots {
    _slots = OkeySlots.sync(_slots, _handIds);
    return _slots;
  }

  @override
  List<OkeyTile> get myHand {
    final hand = state?.hands[playerId] ?? const [];
    final byId = {for (final t in hand) t.id: t};
    final result = <OkeyTile>[];
    for (final id in handSlots) {
      if (id == null) continue;
      final t = byId[id];
      if (t != null) result.add(t);
    }
    return result;
  }

  bool get isHost =>
      state != null && state!.players.isNotEmpty && state!.players.first == playerId;

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
  int opponentTileCount(String id) => state?.hands[id]?.length ?? 0;

  @override
  OkeyTile? topDiscardOf(String id) {
    final d = state?.discards[id];
    return (d != null && d.isNotEmpty) ? d.last : null;
  }

  @override
  String get leftPlayerId {
    final s = state;
    if (s == null || s.players.isEmpty) return '';
    final n = s.players.length;
    final i = s.players.indexOf(playerId);
    if (i == -1) return s.players.first;
    return s.players[(i - 1 + n) % n];
  }

  @override
  OkeyTile? get takeableDiscard => topDiscardOf(leftPlayerId);

  @override
  OkeyTile? get myLastDiscard => topDiscardOf(playerId);

  @override
  bool get canFinish {
    final s = state;
    if (s == null || !isMyTurn || !s.hasDrawn) return false;
    final hand = s.hands[playerId] ?? const [];
    if (hand.length != 15) return false;
    return OkeyMeldSolver.winningDiscard(hand, s.isOkey) != null;
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

  Future<void> startGame() async {
    final id = gameId;
    if (id == null) return;
    await _service.startGame(gameId: id, playerId: playerId);
  }

  @override
  void arrangeHand({required bool byGroups}) {
    final s = state;
    if (s == null) return;
    _slots = List<String?>.from(OkeyHandOrder.sorted(
      s.hands[playerId] ?? const [],
      byGroups: byGroups,
      isOkey: s.isOkey,
    ));
    notifyListeners();
  }

  @override
  void placeTile(String tileId, int slotIndex) {
    _slots = OkeySlots.place(_slots, _handIds, tileId, slotIndex);
    notifyListeners();
  }

  @override
  Future<void> drawFromStack() async {
    final id = gameId;
    if (id == null) return;
    await _service.drawFromStack(gameId: id, playerId: playerId);
  }

  @override
  Future<void> drawFromDiscard() async {
    final id = gameId;
    if (id == null) return;
    await _service.drawFromDiscard(gameId: id, playerId: playerId);
  }

  @override
  Future<void> discard(OkeyTile tile) async {
    final id = gameId;
    if (id == null) return;
    await _service.discard(gameId: id, playerId: playerId, tileId: tile.id);
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
    _slots = const [];
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

  String _friendlyError(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
