import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/okey_board_controller.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import '../services/okey_engine.dart';
import '../services/okey_game_service.dart';
import '../services/okey_hand_order.dart';
import '../services/okey_meld_solver.dart';
import '../../services/player_identity.dart';
import '../../services/afk_config.dart';

/// Uygulama genelinde (online) Okey oyun durumunu tutar ve UI ile
/// [OkeyGameService] arasında köprü kurar.
class OkeyOnlineProvider extends ChangeNotifier implements OkeyBoardController {
  static const int maxNameLength = 8;
  static const int maxPlayers = OkeyEngine.maxPlayers;

  final OkeyGameService _service = OkeyGameService();
  /// Bu oyuncunun kimliği — Firebase anonim oturumunun UID'si.
  /// Firestore kuralları yazma yetkisini buna göre veriyor
  /// (bkz. [PlayerIdentity], firestore.rules).
  final String playerId = PlayerIdentity.current();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  OkeyGameState? state;
  String? error;
  List<String?> _slots = const [];

  StreamSubscription<OkeyGameState?>? _sub;
  Timer? _afkTimer;

  /// Online çekme/alma sırasında Firestore transaction bitmeden UI'ı
  /// güncellemek için tutulan "bekleyen" taş. Stale snapshot'ların
  /// optimistic durumu geri silmesini engeller (bkz. [_subscribe]).
  String? _pendingDrawnTileId;

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
    return OkeyMeldSolver.winningDiscard(hand, s.okeyColor, s.okeyNumber) != null;
  }

  Future<void> createGame(String name, {String? photo}) async {
    error = null;
    _playerName = _normalizeName(name);
    try {
      final id =
          await _service.createGame(playerId, _playerName!, photo: photo);
      _subscribe(id);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> joinGame(String code, String name, {String? photo}) async {
    error = null;
    _playerName = _normalizeName(name);
    final id = code.toUpperCase().trim();
    try {
      await _service.joinGame(id, playerId, _playerName!, photo: photo);
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
    final previous = state;
    if (id == null || previous == null) return;
    // Optimistic: motoru yerelde uygula — UI (ıstaka drop) Firestore
    // round-trip beklemeden taşı göstersin. Yazma arka planda gider.
    final optimistic =
        OkeyEngine.drawFromStack(state: previous, playerId: playerId);
    if (optimistic == null) return;
    _applyOptimisticDraw(previous: previous, optimistic: optimistic);
    unawaited(_commitDraw(
      previous: previous,
      persist: () => _service.drawFromStack(gameId: id, playerId: playerId),
    ));
  }

  @override
  Future<void> drawFromDiscard() async {
    final id = gameId;
    final previous = state;
    if (id == null || previous == null) return;
    final optimistic =
        OkeyEngine.drawFromDiscard(state: previous, playerId: playerId);
    if (optimistic == null) return;
    _applyOptimisticDraw(previous: previous, optimistic: optimistic);
    unawaited(_commitDraw(
      previous: previous,
      persist: () => _service.drawFromDiscard(gameId: id, playerId: playerId),
    ));
  }

  /// Yerel motor sonucunu uygular. [notifyListeners] çağrılmaz — çağıran
  /// taraf hemen ardından [placeTile] ile doğru boşluğa koyup tek bildirim
  /// yapar; burada bildirse taş bir an varsayılan yuvada "zıplardı".
  void _applyOptimisticDraw({
    required OkeyGameState previous,
    required OkeyGameState optimistic,
  }) {
    state = optimistic.copyWith(
      turnStartedAt: AfkConfig.nowMs(),
      afkStrikes: AfkConfig.resetStrike(previous.afkStrikes, playerId),
    );
    _pendingDrawnTileId = _newTileId(previous, optimistic);
    // placeTile notify edecek; AFK saatini şimdiden kur.
    _armAfkWatch();
  }

  String? _newTileId(OkeyGameState before, OkeyGameState after) {
    final beforeIds =
        (before.hands[playerId] ?? const []).map((t) => t.id).toSet();
    for (final t in after.hands[playerId] ?? const []) {
      if (!beforeIds.contains(t.id)) return t.id;
    }
    return null;
  }

  Future<void> _commitDraw({
    required OkeyGameState previous,
    required Future<OkeyGameState?> Function() persist,
  }) async {
    try {
      final result = await persist();
      if (result != null) {
        state = result;
        // [_pendingDrawnTileId] bilerek burada temizlenmez — transaction
        // döndükten sonra hâlâ yoldaki eski snapshot optimistic eli silmesin;
        // taş sunucu anlık görüntüsünde görünince [_subscribe] temizler.
      } else {
        // Sunucu mutasyonu reddetti (el değiştirilemedi) — geri al.
        state = previous;
        _pendingDrawnTileId = null;
        notifyListeners();
      }
    } catch (e) {
      state = previous;
      _pendingDrawnTileId = null;
      error = _friendlyError(e);
      notifyListeners();
    }
  }

  @override
  Future<void> discard(OkeyTile tile) async {
    final id = gameId;
    if (id == null) return;
    // Atılan taşı elden anında kaldır — gecikmeli dinleyiciyi beklersek taş
    // bir an için eski yuvasına "geri dönüp" sonra kaybolur gibi görünüyordu.
    final result =
        await _service.discard(gameId: id, playerId: playerId, tileId: tile.id);
    if (result != null) {
      state = result;
      notifyListeners();
    }
  }

  @override
  Future<void> finishDiscard(OkeyTile tile) async {
    final id = gameId;
    if (id == null) return;
    final result = await _service.finishDiscard(
        gameId: id, playerId: playerId, tileId: tile.id);
    if (result != null) {
      state = result;
      notifyListeners();
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
    _afkTimer?.cancel();
    _afkTimer = null;
    gameId = null;
    state = null;
    error = null;
    _slots = const [];
    _pendingDrawnTileId = null;
    notifyListeners();
  }

  void _subscribe(String id) {
    gameId = id;
    _pendingDrawnTileId = null;
    _sub?.cancel();
    _sub = _service.watchGame(id).listen((s) {
      // Optimistic çekme/alma yazılana kadar gelen eski snapshot'lar eli
      // geri alırdı; bekleyen taş henüz sunucuda yoksa bu güncellemeyi atla.
      final pending = _pendingDrawnTileId;
      if (pending != null && s != null) {
        final hand = s.hands[playerId] ?? const [];
        final caughtUp = hand.any((t) => t.id == pending);
        if (!caughtUp && s.currentTurn == playerId) {
          return;
        }
        _pendingDrawnTileId = null;
      }
      state = s;
      notifyListeners();
      _armAfkWatch();
    });
    notifyListeners();
  }

  void _armAfkWatch() {
    _afkTimer?.cancel();
    final s = state;
    final id = gameId;
    if (id == null || s == null || s.status != 'playing') return;
    if (s.currentTurn.isEmpty) return;
    final wait = AfkConfig.remainingMs(s.turnStartedAt);
    _afkTimer = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () async {
      if (gameId != id) return;
      await _service.resolveAfk(gameId: id);
      _armAfkWatch();
    });
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
    _afkTimer?.cancel();
    super.dispose();
  }
}
