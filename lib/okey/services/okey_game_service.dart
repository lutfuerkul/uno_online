import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/afk_config.dart';
import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import 'okey_bot_service.dart';
import 'okey_engine.dart';

/// Firestore ile tüm Okey oyun iletişimini yürütür: oda kurma, katılma,
/// kurucunun başlatması, çekme/atma ve oyunu canlı dinleme. Kurallar
/// [OkeyEngine] üzerinden yürütülür.
class OkeyGameService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('okey_games');

  Future<String> createGame(String playerId, String name, {String? photo}) async {
    final code = _generateCode();
    await _games.doc(code).set({
      'status': 'waiting',
      'players': [playerId],
      'playerNames': {playerId: name},
      'playerPhotos': {if (photo != null && photo.isNotEmpty) playerId: photo},
      'hands': <String, dynamic>{},
      'drawPile': <dynamic>[],
      'discards': <String, dynamic>{},
      'indicator': null,
      'currentTurn': '',
      'hasDrawn': false,
      'drawnFromDiscardId': null,
      'lastAction': null,
      'winner': null,
      'winners': <dynamic>[],
      'finishedByOkey': false,
      'finishedByPair': false,
      'scores': <String, dynamic>{},
      'cumulativeScores': <String, dynamic>{},
      'turnStartedAt': 0,
      'afkStrikes': <String, dynamic>{},
      'readyPlayers': <dynamic>[],
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return code;
  }

  Future<void> joinGame(String gameId, String playerId, String name,
      {String? photo}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Oda bulunamadı: $gameId');
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
      if (players.length >= OkeyEngine.maxPlayers) {
        throw Exception('Oda dolu (en fazla ${OkeyEngine.maxPlayers} kişi).');
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

  Future<void> startGame({required String gameId, required String playerId}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'waiting') return;
      final players = List<String>.from(data['players'] as List? ?? []);
      if (players.isEmpty || players.first != playerId) return; // sadece kurucu
      if (!OkeyEngine.allowedPlayerCounts.contains(players.length)) return;
      final ready = List<String>.from(data['readyPlayers'] as List? ?? []);
      if (!_allOthersReady(players, ready)) return;

      final names = Map<String, String>.from(
        (data['playerNames'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final photos = Map<String, String>.from(
        (data['playerPhotos'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      // Oyundan çıkılmadıkça (rövanşlarda da) toplam puan tablosu korunur.
      final cumulativeScores = Map<String, int>.from(
        (data['cumulativeScores'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
      final fresh = OkeyEngine.dealNewGame(
        id: gameId,
        players: players,
        playerNames: names,
        playerPhotos: photos,
        cumulativeScores: cumulativeScores,
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

  Stream<OkeyGameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) =>
              snap.exists ? OkeyGameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  /// Yeni durumu (yazılan hâliyle) döndürür. Çağıran taraf (online
  /// provider) çekmeyi önce yerelde optimistic uygular; bu sonuç
  /// transaction doğrulaması / eşitleme içindir.
  Future<OkeyGameState?> drawFromStack({
    required String gameId,
    required String playerId,
  }) {
    return _mutate(
      gameId,
      (game) => OkeyEngine.drawFromStack(state: game, playerId: playerId),
      manualPlayerId: playerId,
    );
  }

  Future<OkeyGameState?> drawFromDiscard({
    required String gameId,
    required String playerId,
  }) {
    return _mutate(
      gameId,
      (game) => OkeyEngine.drawFromDiscard(state: game, playerId: playerId),
      manualPlayerId: playerId,
    );
  }

  /// bkz. drawFromStack — sonucu hemen döndürür ki çağıran taraf attığı
  /// taşı elinden, gecikmeli dinleyiciyi beklemeden anında kaldırabilsin.
  Future<OkeyGameState?> discard({
    required String gameId,
    required String playerId,
    required String tileId,
  }) {
    return _mutate(gameId, (game) {
      final hand = game.hands[playerId] ?? const <OkeyTile>[];
      final idx = hand.indexWhere((t) => t.id == tileId);
      if (idx == -1) return null;
      return OkeyEngine.discard(
          state: game, playerId: playerId, tile: hand[idx]);
    }, manualPlayerId: playerId);
  }

  Future<OkeyGameState?> finishDiscard({
    required String gameId,
    required String playerId,
    required String tileId,
  }) {
    return _mutate(gameId, (game) {
      final hand = game.hands[playerId] ?? const <OkeyTile>[];
      final idx = hand.indexWhere((t) => t.id == tileId);
      if (idx == -1) return null;
      return OkeyEngine.finishDiscard(
          state: game, playerId: playerId, tile: hand[idx]);
    }, manualPlayerId: playerId);
  }

  Future<OkeyGameState?> resolveAfk({required String gameId}) {
    return _mutate(gameId, (game) {
      if (game.status != 'playing') return null;
      final playerId = game.currentTurn;
      if (playerId.isEmpty) return null;
      if (!AfkConfig.isExpired(game.turnStartedAt)) return null;

      final strikes = game.afkStrikes[playerId] ?? 0;
      if (strikes >= AfkConfig.kickAfterStrikes - 1) {
        return OkeyEngine.leavePlayer(state: game, playerId: playerId);
      }
      return _autoMove(game, playerId);
    }, afk: true);
  }

  static OkeyGameState? _autoMove(OkeyGameState game, String playerId) {
    var cur = game;
    if (!cur.hasDrawn) {
      final decision = OkeyBotService.decide(cur, playerId);
      final drawn = decision.fromDiscard
          ? OkeyEngine.drawFromDiscard(state: cur, playerId: playerId)
          : OkeyEngine.drawFromStack(state: cur, playerId: playerId);
      cur = drawn ??
          OkeyEngine.drawFromStack(state: cur, playerId: playerId) ??
          cur;
      if (!cur.hasDrawn) return null;
    }
    final decision = OkeyBotService.decide(cur, playerId);
    final tile = decision.tile;
    if (tile == null) return null;
    return OkeyEngine.finishDiscard(state: cur, playerId: playerId, tile: tile) ??
        OkeyEngine.discard(state: cur, playerId: playerId, tile: tile);
  }

  Future<OkeyGameState?> _mutate(
    String gameId,
    OkeyGameState? Function(OkeyGameState game) apply, {
    String? manualPlayerId,
    bool afk = false,
  }) {
    final ref = _games.doc(gameId);
    return _db.runTransaction<OkeyGameState?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final game = OkeyGameState.fromMap(gameId, snap.data()!);
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

  OkeyGameState _stampAfk({
    required OkeyGameState previous,
    required OkeyGameState next,
    String? manualPlayerId,
    bool afk = false,
  }) {
    final now = AfkConfig.nowMs();
    var strikes = Map<String, int>.from(next.afkStrikes);
    if (manualPlayerId != null) {
      strikes = AfkConfig.resetStrike(strikes, manualPlayerId);
    } else if (afk) {
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
        final game = OkeyGameState.fromMap(gameId, snap.data()!);
        if (!game.players.contains(playerId)) return;
        final result = OkeyEngine.leavePlayer(state: game, playerId: playerId);
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
        'drawPile': <dynamic>[],
        'discards': <String, dynamic>{},
        'indicator': null,
        'currentTurn': '',
        'hasDrawn': false,
        'drawnFromDiscardId': null,
        'lastAction': null,
        'winner': null,
        'winners': <dynamic>[],
        'finishedByOkey': false,
        'finishedByPair': false,
        'scores': <String, dynamic>{},
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
