import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/uno_board_controller.dart';
import '../models/uno_card.dart';
import '../services/game_service.dart';
import '../services/uno_engine.dart';
import '../services/player_identity.dart';
import '../services/afk_config.dart';

/// Uygulama genelinde (online) oyun durumunu tutar ve UI ile [GameService]
/// arasında köprü kurar.
class GameProvider extends ChangeNotifier implements UnoBoardController {
  static const int maxNameLength = 8;
  static const int maxOppCardVisual = 4;
  static const int maxPlayers = UnoEngine.maxPlayers;

  final GameService _service = GameService();

  /// Bu oyuncunun kimliği — Firebase anonim oturumunun UID'si.
  /// Firestore kuralları yazma yetkisini buna göre veriyor
  /// (bkz. [PlayerIdentity], firestore.rules).
  final String playerId = PlayerIdentity.current();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  GameState? state;
  String? error;

  StreamSubscription<GameState?>? _sub;
  Timer? _afkTimer;

  /// Optimistic hamleler için: Firestore yazılana kadar stale snapshot'ların
  /// yerel sonucu geri silmesini engeller (Okey draw deseni).
  String? _pendingDrawnCardId;
  String? _pendingPlayedCardId;
  bool _pendingPass = false;

  @override
  bool get isMyTurn => state?.currentTurn == playerId;
  @override
  bool get hasDrawn => state?.hasDrawn ?? false;
  @override
  CardColor? get reverseColor => state?.reverseColor;

  bool get isHost => state != null && state!.players.isNotEmpty && state!.players.first == playerId;

  bool get isReady => state?.readyPlayers.contains(playerId) ?? false;

  /// Kurucu dışındaki herkes hazır mı? (başlatma koşulu)
  bool get allOthersReady {
    final s = state;
    if (s == null || s.players.length < 2) return false;
    final host = s.players.first;
    for (final p in s.players) {
      if (p == host) continue;
      if (!s.readyPlayers.contains(p)) return false;
    }
    return true;
  }

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
  String? opponentPhoto(String id) {
    final photo = state?.playerPhotos[id];
    return (photo != null && photo.isNotEmpty) ? photo : null;
  }

  @override
  bool get iWon => state?.winner == playerId;

  /// Verilen kart şu an oynanabilir mi?
  @override
  bool canPlay(UnoCard card) {
    final s = state;
    if (s == null || !isMyTurn) return false;
    return UnoEngine.isPlayable(card, s);
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

  /// Yalnızca kurucu, en az 2 oyuncu varken çağırabilir.
  Future<void> startGame() async {
    final id = gameId;
    if (id == null) return;
    await _service.startGame(gameId: id, playerId: playerId);
  }

  Future<void> setReady(bool ready) async {
    final id = gameId;
    if (id == null) return;
    await _service.setReady(gameId: id, playerId: playerId, ready: ready);
  }

  Future<void> rematch() async {
    final id = gameId;
    if (id == null) return;
    await _service.rematch(id, playerId: playerId);
  }

  @override
  Future<void> playCard(UnoCard card,
      {CardColor? chosenColor, String? targetId}) async {
    final id = gameId;
    final previous = state;
    if (id == null || previous == null) return;
    final optimistic = UnoEngine.playCard(
      state: previous,
      playerId: playerId,
      card: card,
      chosenColor: chosenColor,
      targetId: targetId,
    );
    if (optimistic == null) return;
    state = optimistic.copyWith(
      turnStartedAt: AfkConfig.nowMs(),
      afkStrikes: AfkConfig.resetStrike(previous.afkStrikes, playerId),
    );
    _pendingPlayedCardId = card.id;
    notifyListeners();
    _armAfkWatch();
    unawaited(_commitMove(
      previous: previous,
      persist: () => _service.playCard(
        gameId: id,
        playerId: playerId,
        cardId: card.id,
        chosenColor: chosenColor,
        targetId: targetId,
      ),
      clearPending: () => _pendingPlayedCardId = null,
    ));
  }

  @override
  Future<void> drawCard() async {
    final id = gameId;
    final previous = state;
    if (id == null || previous == null) return;
    final optimistic =
        UnoEngine.drawCard(state: previous, playerId: playerId);
    if (optimistic == null) return;
    final newId = _newCardId(previous, optimistic);
    state = optimistic.copyWith(
      turnStartedAt: AfkConfig.nowMs(),
      afkStrikes: AfkConfig.resetStrike(previous.afkStrikes, playerId),
    );
    _pendingDrawnCardId = newId;
    notifyListeners();
    _armAfkWatch();
    unawaited(_commitMove(
      previous: previous,
      persist: () => _service.drawCard(gameId: id, playerId: playerId),
      clearPending: () => _pendingDrawnCardId = null,
    ));
  }

  @override
  Future<void> pass() async {
    final id = gameId;
    final previous = state;
    if (id == null || previous == null) return;
    final optimistic = UnoEngine.pass(state: previous, playerId: playerId);
    if (optimistic == null) return;
    state = optimistic.copyWith(
      turnStartedAt: AfkConfig.nowMs(),
      afkStrikes: AfkConfig.resetStrike(previous.afkStrikes, playerId),
    );
    _pendingPass = true;
    notifyListeners();
    _armAfkWatch();
    unawaited(_commitMove(
      previous: previous,
      persist: () => _service.pass(gameId: id, playerId: playerId),
      clearPending: () => _pendingPass = false,
    ));
  }

  String? _newCardId(GameState before, GameState after) {
    final beforeIds =
        (before.hands[playerId] ?? const []).map((c) => c.id).toSet();
    for (final c in after.hands[playerId] ?? const []) {
      if (!beforeIds.contains(c.id)) return c.id;
    }
    return null;
  }

  Future<void> _commitMove({
    required GameState previous,
    required Future<GameState?> Function() persist,
    required void Function() clearPending,
  }) async {
    try {
      final result = await persist();
      if (result != null) {
        state = result;
        // Pending, eşleşen snapshot gelince [_subscribe] içinde temizlenir —
        // yoldaki eski snapshot optimistic sonucu silmesin.
      } else {
        state = previous;
        clearPending();
        notifyListeners();
      }
    } catch (e) {
      state = previous;
      clearPending();
      error = _friendlyError(e);
      notifyListeners();
    }
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
    _afkTimer?.cancel();
    _afkTimer = null;
    gameId = null;
    state = null;
    error = null;
    _clearPending();
    notifyListeners();
  }

  void _clearPending() {
    _pendingDrawnCardId = null;
    _pendingPlayedCardId = null;
    _pendingPass = false;
  }

  void _subscribe(String id) {
    gameId = id;
    _clearPending();
    _sub?.cancel();
    _sub = _service.watchGame(id).listen((s) {
      if (_shouldIgnoreStale(s)) return;
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
      // Snapshot gelince yeniden kurulur; gelmezse kısa sonra tekrar dene.
      _armAfkWatch();
    });
  }

  /// Optimistic hamle yazılana kadar gelen eski snapshot'ları atlar.
  bool _shouldIgnoreStale(GameState? s) {
    if (s == null) return false;

    if (state?.status == 'finished' && s.status == 'playing') {
      return true;
    }
    if (s.status == 'waiting') {
      _pendingDrawnCardId = null;
      _pendingPlayedCardId = null;
      _pendingPass = false;
    }

    final drawn = _pendingDrawnCardId;
    if (drawn != null) {
      final hand = s.hands[playerId] ?? const [];
      final caughtUp = hand.any((c) => c.id == drawn);
      if (!caughtUp && s.currentTurn == playerId) return true;
      _pendingDrawnCardId = null;
    }

    final played = _pendingPlayedCardId;
    if (played != null) {
      final hand = s.hands[playerId] ?? const [];
      final stillInHand = hand.any((c) => c.id == played);
      if (stillInHand && s.currentTurn == playerId && s.status == 'playing') {
        return true;
      }
      _pendingPlayedCardId = null;
    }

    if (_pendingPass) {
      if (s.currentTurn == playerId && s.status == 'playing') return true;
      _pendingPass = false;
    }

    return false;
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
    _afkTimer?.cancel();
    super.dispose();
  }
}