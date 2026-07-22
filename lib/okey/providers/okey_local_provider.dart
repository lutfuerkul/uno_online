import 'package:flutter/foundation.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_bot_service.dart';
import '../services/okey_engine.dart';
import '../services/okey_hand_order.dart';
import '../services/okey_meld_solver.dart';

/// "Bilgisayara Karşı Oyna" modunu yöneten yerel (Firestore'suz) Okey motoru.
/// Kurallar [OkeyEngine] üzerinden online modla birebir aynıdır; tek fark bu
/// motorun durumu cihaz içinde tutması ve rakiplerin bot olmasıdır.
class OkeyLocalProvider extends ChangeNotifier implements OkeyBoardController {
  static const String humanId = 'you';
  static const Duration _botDrawDelay = Duration(milliseconds: 1100);
  static const Duration _botDiscardDelay = Duration(milliseconds: 900);

  @override
  OkeyGameState? state;

  int _session = 0;
  bool _botLoopRunning = false;
  List<String> _order = const [];

  @override
  String get selfId => humanId;

  @override
  bool get isMyTurn => state?.status == 'playing' && state?.currentTurn == humanId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;

  @override
  List<OkeyTile> get myHand =>
      OkeyHandOrder.apply(state?.hands[humanId] ?? const [], _order);

  @override
  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

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
    final i = s.players.indexOf(humanId);
    if (i == -1) return s.players.first;
    return s.players[(i - 1 + n) % n];
  }

  @override
  OkeyTile? get takeableDiscard => topDiscardOf(leftPlayerId);

  @override
  OkeyTile? get myLastDiscard => topDiscardOf(humanId);

  @override
  bool get canFinish {
    final s = state;
    if (s == null || !isMyTurn || !s.hasDrawn) return false;
    final hand = s.hands[humanId] ?? const [];
    if (hand.length != 15) return false;
    return OkeyMeldSolver.winningDiscard(hand, s.isOkey) != null;
  }

  String _lastPlayerName = '';
  int _lastTotalPlayers = 4;

  void startGame({required String playerName, required int totalPlayers}) {
    _lastPlayerName = playerName;
    _lastTotalPlayers = totalPlayers;
    _session++;
    _order = const [];

    final players = ['you', for (var i = 1; i < totalPlayers; i++) 'bot$i'];
    final names = <String, String>{
      'you': playerName.isEmpty ? 'Sen' : playerName,
      for (var i = 1; i < totalPlayers; i++) 'bot$i': '🤖 Oyuncu $i',
    };

    state =
        OkeyEngine.dealNewGame(id: 'local', players: players, playerNames: names);
    notifyListeners();
    _scheduleBotLoop(_session);
  }

  void rematch() =>
      startGame(playerName: _lastPlayerName, totalPlayers: _lastTotalPlayers);

  @override
  Future<void> leaveGame() async {
    _session++;
    state = null;
    _order = const [];
    notifyListeners();
  }

  @override
  void arrangeHand({required bool byGroups}) {
    final s = state;
    if (s == null) return;
    _order = OkeyHandOrder.sorted(
      s.hands[humanId] ?? const [],
      byGroups: byGroups,
      isOkey: s.isOkey,
    );
    notifyListeners();
  }

  @override
  void moveTile(String draggedId, String targetId, {bool after = false}) {
    if (draggedId == targetId) return;
    final ids = myHand.map((t) => t.id).toList();
    if (!ids.contains(draggedId)) return;
    ids.remove(draggedId);
    final ti = ids.indexOf(targetId);
    if (ti < 0) {
      ids.add(draggedId);
    } else {
      ids.insert(after ? ti + 1 : ti, draggedId);
    }
    _order = ids;
    notifyListeners();
  }

  @override
  Future<void> drawFromStack() async {
    final s = state;
    if (s == null) return;
    final result = OkeyEngine.drawFromStack(state: s, playerId: humanId);
    if (result == null) return;
    state = result;
    notifyListeners();
  }

  @override
  Future<void> drawFromDiscard() async {
    final s = state;
    if (s == null) return;
    final result = OkeyEngine.drawFromDiscard(state: s, playerId: humanId);
    if (result == null) return;
    state = result;
    notifyListeners();
  }

  @override
  Future<void> discard(OkeyTile tile) async {
    final s = state;
    if (s == null) return;
    final result = OkeyEngine.discard(state: s, playerId: humanId, tile: tile);
    if (result == null) return;
    state = result;
    notifyListeners();
    _scheduleBotLoop(_session);
  }

  /// Sıradaki oyuncu(lar) bot olduğu sürece kısa gecikmelerle çeker+atar;
  /// insanın sırası gelince ya da oyun bitince durur.
  Future<void> _scheduleBotLoop(int session) async {
    if (_botLoopRunning) return;
    _botLoopRunning = true;
    try {
      while (true) {
        final s = state;
        if (s == null || s.status != 'playing' || session != _session) break;
        if (s.currentTurn == humanId) break;
        final botId = s.currentTurn;

        // 1) Çekme
        await Future.delayed(_botDrawDelay);
        if (session != _session) break;
        var cur = state;
        if (cur == null || cur.status != 'playing' || cur.currentTurn != botId) {
          continue;
        }
        if (!cur.hasDrawn) {
          final decision = OkeyBotService.decide(cur, botId);
          final drew = decision.fromDiscard
              ? OkeyEngine.drawFromDiscard(state: cur, playerId: botId)
              : OkeyEngine.drawFromStack(state: cur, playerId: botId);
          // Iskarta alınamıyorsa desteden çek.
          state = drew ??
              OkeyEngine.drawFromStack(state: cur, playerId: botId) ??
              cur;
          notifyListeners();
        }

        // 2) Atma / el açma
        await Future.delayed(_botDiscardDelay);
        if (session != _session) break;
        cur = state;
        if (cur == null || cur.status != 'playing' || cur.currentTurn != botId) {
          continue;
        }
        final decision = OkeyBotService.decide(cur, botId);
        final tile = decision.tile;
        if (tile == null) break;
        final result =
            OkeyEngine.discard(state: cur, playerId: botId, tile: tile);
        if (result == null) break;
        state = result;
        notifyListeners();
      }
    } finally {
      _botLoopRunning = false;
    }
  }
}
