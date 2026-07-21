import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/okey_game_state.dart';
import '../models/okey_tile.dart';
import 'okey_engine.dart';

/// Firestore ile tüm Okey oyun iletişimini yürütür: oda kurma, katılma,
/// kurucunun başlatması, çekme/atma ve oyunu canlı dinleme. Kurallar
/// [OkeyEngine] üzerinden yürütülür.
class OkeyGameService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('okey_games');

  Future<String> createGame(String playerId, String name) async {
    final code = _generateCode();
    await _games.doc(code).set({
      'status': 'waiting',
      'players': [playerId],
      'playerNames': {playerId: name},
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
      'scores': <String, dynamic>{},
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return code;
  }

  Future<void> joinGame(String gameId, String playerId, String name) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Oda bulunamadı: $gameId');
      final data = snap.data()!;
      if (data['status'] != 'waiting') throw Exception('Oyun çoktan başladı.');
      final players = List<String>.from(data['players'] as List? ?? []);
      final names = Map<String, dynamic>.from(data['playerNames'] as Map? ?? {});

      if (players.contains(playerId)) return; // yeniden bağlanma
      if (players.length >= OkeyEngine.maxPlayers) {
        throw Exception('Oda dolu (en fazla ${OkeyEngine.maxPlayers} kişi).');
      }
      final normalized = _normalizeName(name);
      if (_isNameTaken(names, normalized)) {
        throw Exception('Bu isim zaten alınmış. Başka bir isim seç.');
      }
      players.add(playerId);
      names[playerId] = normalized;
      tx.update(ref, {'players': players, 'playerNames': names});
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

      final names = Map<String, String>.from(
        (data['playerNames'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final fresh =
          OkeyEngine.dealNewGame(id: gameId, players: players, playerNames: names);
      tx.update(ref, fresh.toMap());
    });
  }

  Stream<OkeyGameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) =>
              snap.exists ? OkeyGameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  Future<void> drawFromStack({
    required String gameId,
    required String playerId,
  }) async {
    await _mutate(gameId, (game) =>
        OkeyEngine.drawFromStack(state: game, playerId: playerId));
  }

  Future<void> drawFromDiscard({
    required String gameId,
    required String playerId,
  }) async {
    await _mutate(gameId, (game) =>
        OkeyEngine.drawFromDiscard(state: game, playerId: playerId));
  }

  Future<void> discard({
    required String gameId,
    required String playerId,
    required String tileId,
  }) async {
    await _mutate(gameId, (game) {
      final hand = game.hands[playerId] ?? const <OkeyTile>[];
      final idx = hand.indexWhere((t) => t.id == tileId);
      if (idx == -1) return null;
      return OkeyEngine.discard(
          state: game, playerId: playerId, tile: hand[idx]);
    });
  }

  Future<void> _mutate(
    String gameId,
    OkeyGameState? Function(OkeyGameState game) apply,
  ) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = OkeyGameState.fromMap(gameId, snap.data()!);
      final result = apply(game);
      if (result == null) return;
      tx.update(ref, result.toMap());
    });
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
        tx.update(ref, result.toMap());
      });
    } catch (_) {
      // hata olsa da yerelden çık
    }
  }

  Future<void> rematch(String gameId) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'finished') return;
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
        'scores': <String, dynamic>{},
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
