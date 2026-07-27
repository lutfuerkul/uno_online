import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/afk_config.dart';
import '../models/pisti_game_state.dart';
import 'pisti_bot_service.dart';
import 'pisti_engine.dart';

/// Firestore ile tüm Pişti oyun iletişimini yürütür: oda kurma, katılma,
/// kurucunun başlatması, kart oynama/toplama ve oyunu canlı dinleme. Kurallar
/// [PistiEngine] üzerinden yürütülür; bu sınıf yalnızca okuma/yazma/
/// eşzamanlılık (transaction) ile ilgilenir.
class PistiGameService {
  // Getter (final alan değil): Firebase henüz initializeApp() ile
  // başlatılmadıysa PistiGameService()'in kendisi değil, yalnızca gerçekten
  // bir Firestore işlemi yapılmaya çalışıldığında hata fırlatsın diye.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('pisti_games');

  /// Yeni oda kurar ve oda kodunu döndürür. Kurucu, 2-4 kişi katılınca
  /// [startGame] ile oyunu başlatır.
  Future<String> createGame(String playerId, String name, {String? photo}) async {
    final code = _generateCode();
    await _games.doc(code).set({
      'status': 'waiting',
      'players': [playerId],
      'playerNames': {playerId: name},
      'playerPhotos': {if (photo != null && photo.isNotEmpty) playerId: photo},
      'hands': <String, dynamic>{},
      'pile': <dynamic>[],
      'drawPile': <dynamic>[],
      'won': <String, dynamic>{},
      'pistiCount': <String, dynamic>{},
      'jackPistiCount': <String, dynamic>{},
      'lastCapturer': null,
      'lastAction': null,
      'pendingCapture': null,
      'currentTurn': '',
      'winner': null,
      'winners': <dynamic>[],
      'scores': <String, dynamic>{},
      'scoreDetail': <String, dynamic>{},
      'turnStartedAt': 0,
      'afkStrikes': <String, dynamic>{},
      'readyPlayers': <dynamic>[],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return code;
  }

  /// Var olan (bekleme aşamasındaki) odaya katılır. En fazla 4 kişi.
  Future<void> joinGame(String gameId, String playerId, String name,
      {String? photo}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Oda bulunamadı: $gameId');
      }
      final data = snap.data()!;
      final players = List<String>.from(data['players'] as List? ?? []);
      final names = Map<String, dynamic>.from(data['playerNames'] as Map? ?? {});
      final photos =
          Map<String, dynamic>.from(data['playerPhotos'] as Map? ?? {});

      // Rejoin: UID hâlâ odadaysa status'e bakmadan dinlemeye devam.
      if (players.contains(playerId)) return;

      if (data['status'] != 'waiting') {
        throw Exception('Oyun çoktan başladı.');
      }
      if (players.length >= PistiEngine.maxPlayers) {
        throw Exception('Oda dolu (en fazla ${PistiEngine.maxPlayers} kişi).');
      }

      final normalized = _normalizeName(name);
      if (_isNameTaken(names, normalized)) {
        throw Exception('Bu isim zaten alınmış. Başka bir isim seç.');
      }

      players.add(playerId);
      names[playerId] = normalized;
      if (photo != null && photo.isNotEmpty) photos[playerId] = photo;
      tx.update(ref,
          {'players': players, 'playerNames': names, 'playerPhotos': photos});
    });
  }

  /// Yalnızca kurucu; diğerleri hazırken başlatır.
  Future<void> startGame({required String gameId, required String playerId}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'waiting') return;
      final players = List<String>.from(data['players'] as List? ?? []);
      if (players.isEmpty || players.first != playerId) return; // sadece kurucu
      if (!PistiEngine.allowedPlayerCounts.contains(players.length)) return;
      final ready = List<String>.from(data['readyPlayers'] as List? ?? []);
      if (!_allOthersReady(players, ready)) return;

      final names = Map<String, String>.from(
        (data['playerNames'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final photos = Map<String, String>.from(
        (data['playerPhotos'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final fresh = PistiEngine.dealNewGame(
        id: gameId,
        players: players,
        playerNames: names,
        playerPhotos: photos,
      );
      tx.update(ref, {...fresh.toMap(), 'readyPlayers': <dynamic>[]});
    });
  }

  Future<void> setReady({
    required String gameId,
    required String playerId,
    required bool ready,
  }) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'waiting') return;
      final players = List<String>.from(data['players'] as List? ?? []);
      if (!players.contains(playerId)) return;
      if (players.isNotEmpty && players.first == playerId) return;
      final readyList = List<String>.from(data['readyPlayers'] as List? ?? []);
      if (ready) {
        if (!readyList.contains(playerId)) readyList.add(playerId);
      } else {
        readyList.remove(playerId);
      }
      tx.update(ref, {'readyPlayers': readyList});
    });
  }

  static bool _allOthersReady(List<String> players, List<String> ready) {
    if (players.length < 2) return false;
    final host = players.first;
    for (final p in players) {
      if (p == host) continue;
      if (!ready.contains(p)) return false;
    }
    return true;
  }

  Stream<PistiGameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) => snap.exists ? PistiGameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  Future<PistiGameState?> playCard({
    required String gameId,
    required String playerId,
    required String cardId,
  }) {
    return _mutate(gameId, (game) {
      final hand = game.hands[playerId] ?? const [];
      final idx = hand.indexWhere((c) => c.id == cardId);
      if (idx == -1) return null;
      return PistiEngine.playCard(
          state: game, playerId: playerId, card: hand[idx]);
    }, manualPlayerId: playerId);
  }

  /// Faz B: masa toplanır (yakalayan oyuncuya), sıra ilerler.
  Future<PistiGameState?> collectPile(String gameId) {
    return _mutate(gameId, (game) => PistiEngine.collectPile(state: game));
  }

  /// AFK: 60 sn → otomatik kart; 3. AFK → kick.
  /// pendingCapture takılıysa süre dolunca herkes toplayabilir (strike yok).
  Future<PistiGameState?> resolveAfk({required String gameId}) {
    return _mutate(gameId, (game) {
      if (game.status != 'playing') return null;
      if (!AfkConfig.isExpired(game.turnStartedAt)) return null;

      if (game.pendingCapture != null) {
        return PistiEngine.collectPile(state: game);
      }

      final playerId = game.currentTurn;
      if (playerId.isEmpty) return null;
      final strikes = game.afkStrikes[playerId] ?? 0;
      if (strikes >= AfkConfig.kickAfterStrikes - 1) {
        return PistiEngine.leavePlayer(state: game, playerId: playerId);
      }
      final hand = game.hands[playerId] ?? const [];
      if (hand.isEmpty) return null;
      final card = PistiBotService.choose(game, playerId);
      return PistiEngine.playCard(state: game, playerId: playerId, card: card);
    }, afk: true);
  }

  Future<PistiGameState?> _mutate(
    String gameId,
    PistiGameState? Function(PistiGameState game) apply, {
    String? manualPlayerId,
    bool afk = false,
  }) {
    final ref = _games.doc(gameId);
    return _db.runTransaction<PistiGameState?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final game = PistiGameState.fromMap(gameId, snap.data()!);
      final result = apply(game);
      if (result == null) return null;
      final stamped = _stampAfk(
        previous: game,
        next: result,
        manualPlayerId: manualPlayerId,
        afk: afk,
      );
      tx.update(ref, stamped.toMap());
      return stamped;
    });
  }

  PistiGameState _stampAfk({
    required PistiGameState previous,
    required PistiGameState next,
    String? manualPlayerId,
    bool afk = false,
  }) {
    final now = AfkConfig.nowMs();
    var strikes = Map<String, int>.from(next.afkStrikes);

    if (manualPlayerId != null) {
      strikes = AfkConfig.resetStrike(strikes, manualPlayerId);
    } else if (afk && previous.pendingCapture == null) {
      // pendingCapture kurtarma strike sayılmaz.
      final victim = previous.currentTurn;
      if (victim.isNotEmpty && next.players.contains(victim)) {
        strikes = AfkConfig.bumpStrike(strikes, victim);
      } else if (victim.isNotEmpty) {
        strikes = Map<String, int>.from(strikes)..remove(victim);
      }
    }

    return next.copyWith(turnStartedAt: now, afkStrikes: strikes);
  }

  Future<void> leaveRoom({required String gameId, required String playerId}) async {
    final ref = _games.doc(gameId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final game = PistiGameState.fromMap(gameId, snap.data()!);
        if (!game.players.contains(playerId)) return;
        final result = PistiEngine.leavePlayer(state: game, playerId: playerId);
        final stamped = _stampAfk(previous: game, next: result);
        tx.update(ref, stamped.toMap());
      });
    } catch (_) {
      // hata olsa da yerelden çık
    }
  }

  Future<void> rematch(String gameId, {required String playerId}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'finished') return;
      final players = List<String>.from(data['players'] as List? ?? []);
      if (players.isEmpty || players.first != playerId) return;
      tx.update(ref, {
        'status': 'waiting',
        'hands': <String, dynamic>{},
        'pile': <dynamic>[],
        'drawPile': <dynamic>[],
        'won': <String, dynamic>{},
        'pistiCount': <String, dynamic>{},
        'jackPistiCount': <String, dynamic>{},
        'lastCapturer': null,
        'lastAction': null,
        'pendingCapture': null,
        'currentTurn': '',
        'winner': null,
        'winners': <dynamic>[],
        'scores': <String, dynamic>{},
        'scoreDetail': <String, dynamic>{},
        'turnStartedAt': 0,
        'afkStrikes': <String, dynamic>{},
        'readyPlayers': <dynamic>[],
      });
    });
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(5, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  String _normalizeName(String name) {
    final trimmed = name.trim();
    return trimmed.length > 12 ? trimmed.substring(0, 12) : trimmed;
  }

  String _nameKey(String name) => _normalizeName(name).toLowerCase();

  bool _isNameTaken(Map<String, dynamic> names, String name) {
    final key = _nameKey(name);
    if (key.isEmpty) return false;
    for (final entry in names.entries) {
      if (_nameKey(entry.value?.toString() ?? '') == key) return true;
    }
    return false;
  }
}
