import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/pisti_board_controller.dart';
import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';
import '../services/pisti_engine.dart';
import '../services/pisti_game_service.dart';
import '../../services/player_identity.dart';
import '../../services/afk_config.dart';

/// Uygulama genelinde (online) Pişti oyun durumunu tutar ve UI ile
/// [PistiGameService] arasında köprü kurar.
class PistiOnlineProvider extends ChangeNotifier implements PistiBoardController {
  static const int maxNameLength = 8;
  static const int maxPlayers = PistiEngine.maxPlayers;

  final PistiGameService _service = PistiGameService();

  /// Bu oyuncunun kimliği — Firebase anonim oturumunun UID'si.
  /// Firestore kuralları yazma yetkisini buna göre veriyor
  /// (bkz. [PlayerIdentity], firestore.rules).
  final String playerId = PlayerIdentity.current();

  @override
  String get selfId => playerId;

  String? _playerName;
  String? gameId;
  @override
  PistiGameState? state;
  String? error;

  StreamSubscription<PistiGameState?>? _sub;
  Timer? _collectTimer;
  Timer? _afkTimer;

  /// Optimistic play: kart hâlâ elde görünen stale snapshot'ları yok say.
  String? _pendingPlayedCardId;

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
  @override
  String? opponentPhoto(String id) {
    final photo = state?.playerPhotos[id];
    return (photo != null && photo.isNotEmpty) ? photo : null;
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

  /// Yalnızca kurucu, oyuncu sayısı 2, 3 ya da 4 iken çağırabilir.
  Future<void> startGame() async {
    final id = gameId;
    if (id == null) return;
    await _service.startGame(gameId: id, playerId: playerId);
  }

  @override
  Future<void> playCard(PistiCard card) async {
    final id = gameId;
    final previous = state;
    if (id == null || previous == null) return;
    final optimistic =
        PistiEngine.playCard(state: previous, playerId: playerId, card: card);
    if (optimistic == null) return;
    state = optimistic.copyWith(
      turnStartedAt: AfkConfig.nowMs(),
      afkStrikes: AfkConfig.resetStrike(previous.afkStrikes, playerId),
    );
    _pendingPlayedCardId = card.id;
    notifyListeners();
    _armAfkWatch();
    // Toplama burada zamanlanmaz — yalnızca gerçek snapshot'ta
    // (_maybeScheduleCollect). Optimistic pendingCapture ile timer kurmak
    // sunucu yazılmadan collectPile yarışı yaratırdı.
    unawaited(_commitPlay(previous: previous, gameId: id, cardId: card.id));
  }

  Future<void> _commitPlay({
    required PistiGameState previous,
    required String gameId,
    required String cardId,
  }) async {
    try {
      final result = await _service.playCard(
          gameId: gameId, playerId: playerId, cardId: cardId);
      if (result != null) {
        state = result;
        // Pending snapshot yakalayınca temizlenir.
      } else {
        state = previous;
        _pendingPlayedCardId = null;
        notifyListeners();
      }
    } catch (e) {
      state = previous;
      _pendingPlayedCardId = null;
      error = _friendlyError(e);
      notifyListeners();
    }
  }

  /// Masayı yakalayan bensem, oynanan kart masada kısa süre görünsün diye
  /// bir gecikmeyle [PistiGameService.collectPile] çağırır. Her snapshot'ta
  /// çağrılır; zamanlayıcı zaten kuruluysa ya da toplanacak bir şey yoksa
  /// hiçbir şey yapmaz.
  void _maybeScheduleCollect() {
    if (_collectTimer != null) return;
    final s = state;
    final id = gameId;
    if (id == null || s == null || s.status != 'playing') return;
    final pending = s.pendingCapture;
    if (pending == null || pending.by != playerId) return;
    final delayMs = pending.endsGame ? 2000 : 1200;
    _collectTimer = Timer(Duration(milliseconds: delayMs), () {
      _collectTimer = null;
      if (gameId == id) _service.collectPile(id);
    });
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
    _collectTimer?.cancel();
    _collectTimer = null;
    _afkTimer?.cancel();
    _afkTimer = null;
    gameId = null;
    state = null;
    error = null;
    _pendingPlayedCardId = null;
    notifyListeners();
  }

  void _subscribe(String id) {
    gameId = id;
    _pendingPlayedCardId = null;
    _sub?.cancel();
    _sub = _service.watchGame(id).listen((s) {
      if (_shouldIgnoreStale(s)) return;
      state = s;
      notifyListeners();
      _maybeScheduleCollect();
      _armAfkWatch();
    });
    notifyListeners();
  }

  void _armAfkWatch() {
    _afkTimer?.cancel();
    final s = state;
    final id = gameId;
    if (id == null || s == null || s.status != 'playing') return;
    if (s.currentTurn.isEmpty && s.pendingCapture == null) return;
    final wait = AfkConfig.remainingMs(s.turnStartedAt);
    _afkTimer = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () async {
      if (gameId != id) return;
      await _service.resolveAfk(gameId: id);
      _armAfkWatch();
    });
  }

  bool _shouldIgnoreStale(PistiGameState? s) {
    final played = _pendingPlayedCardId;
    if (played == null || s == null) return false;
    final hand = s.hands[playerId] ?? const [];
    final stillInHand = hand.any((c) => c.id == played);
    // Kart hâlâ eldeyse ve sıra/oyun hâlâ bende / playing ise eski görüntü.
    if (stillInHand &&
        s.currentTurn == playerId &&
        s.pendingCapture == null &&
        s.status == 'playing') {
      return true;
    }
    _pendingPlayedCardId = null;
    return false;
  }

  String _normalizeName(String name) {
    final trimmed = name.trim();
    return trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength) : trimmed;
  }

  String _friendlyError(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    _sub?.cancel();
    _collectTimer?.cancel();
    _afkTimer?.cancel();
    super.dispose();
  }
}
