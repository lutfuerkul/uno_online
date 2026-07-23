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
  List<String?> _slots = const [];

  @override
  String get selfId => humanId;

  @override
  bool get isMyTurn => state?.status == 'playing' && state?.currentTurn == humanId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;

  List<String> get _handIds =>
      (state?.hands[humanId] ?? const []).map((t) => t.id).toList();

  @override
  List<String?> get handSlots {
    _slots = OkeySlots.sync(_slots, _handIds);
    return _slots;
  }

  @override
  List<OkeyTile> get myHand {
    final hand = state?.hands[humanId] ?? const [];
    final byId = {for (final t in hand) t.id: t};
    final result = <OkeyTile>[];
    for (final id in handSlots) {
      if (id == null) continue;
      final t = byId[id];
      if (t != null) result.add(t);
    }
    return result;
  }

  @override
  List<String> get opponents =>
      state?.players.where((p) => p != humanId).toList() ?? const [];

  @override
  String opponentName(String id) => state?.playerNames[id] ?? id;
  @override
  int opponentTileCount(String id) => state?.hands[id]?.length ?? 0;
  @override
  String? opponentPhoto(String id) {
    final photo = state?.playerPhotos[id];
    return (photo != null && photo.isNotEmpty) ? photo : null;
  }

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
    return OkeyMeldSolver.winningDiscard(hand, s.okeyColor, s.okeyNumber) != null;
  }

  String _lastPlayerName = '';
  int _lastTotalPlayers = 4;
  String? _lastPhoto;

  /// Oyundan çıkılmadıkça (rövanşlarda da) korunan toplam puan tablosu.
  Map<String, int> _cumulativeScores = const {};

  void startGame({
    required String playerName,
    required int totalPlayers,
    String? photo,
    bool isRematch = false,
  }) {
    _lastPlayerName = playerName;
    _lastTotalPlayers = totalPlayers;
    _lastPhoto = photo;
    _session++;
    _slots = const [];
    if (!isRematch) _cumulativeScores = const {};

    final players = ['you', for (var i = 1; i < totalPlayers; i++) 'bot$i'];
    final names = <String, String>{
      'you': playerName.isEmpty ? 'Sen' : playerName,
      for (var i = 1; i < totalPlayers; i++) 'bot$i': '🤖 Oyuncu $i',
    };
    final photos = <String, String>{
      if (photo != null && photo.isNotEmpty) 'you': photo,
    };

    state = OkeyEngine.dealNewGame(
      id: 'local',
      players: players,
      playerNames: names,
      playerPhotos: photos,
      cumulativeScores: _cumulativeScores,
    );
    notifyListeners();
    _scheduleBotLoop(_session);
  }

  void rematch() {
    _cumulativeScores = Map.of(state?.cumulativeScores ?? const {});
    startGame(
      playerName: _lastPlayerName,
      totalPlayers: _lastTotalPlayers,
      photo: _lastPhoto,
      isRematch: true,
    );
  }

  @override
  Future<void> leaveGame() async {
    _session++;
    state = null;
    _slots = const [];
    notifyListeners();
  }

  @override
  void arrangeHand({required bool byGroups}) {
    final s = state;
    if (s == null) return;
    _slots = List<String?>.from(OkeyHandOrder.sorted(
      s.hands[humanId] ?? const [],
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

  @override
  Future<void> finishDiscard(OkeyTile tile) async {
    final s = state;
    if (s == null) return;
    final result =
        OkeyEngine.finishDiscard(state: s, playerId: humanId, tile: tile);
    if (result == null) return;
    state = result;
    notifyListeners();
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
        // Önce eli bitirip bitiremeyeceğini dener (göstergeye atış); olmazsa
        // normal atış (Attığım'a atış) yapar.
        final result =
            OkeyEngine.finishDiscard(state: cur, playerId: botId, tile: tile) ??
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
