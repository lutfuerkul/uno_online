import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/pisti_game_state.dart';
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
      if (data['status'] != 'waiting') {
        throw Exception('Oyun çoktan başladı.');
      }
      final players = List<String>.from(data['players'] as List? ?? []);
      final names = Map<String, dynamic>.from(data['playerNames'] as Map? ?? {});
      final photos =
          Map<String, dynamic>.from(data['playerPhotos'] as Map? ?? {});

      if (players.contains(playerId)) return; // yeniden bağlanma
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

  /// Yalnızca kurucu, oyuncu sayısı 2, 3 ya da 4 iken oyunu başlatır.
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
      tx.update(ref, fresh.toMap());
    });
  }

  Stream<PistiGameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) => snap.exists ? PistiGameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  Future<void> playCard({
    required String gameId,
    required String playerId,
    required String cardId,
  }) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = PistiGameState.fromMap(gameId, snap.data()!);
      final hand = game.hands[playerId] ?? const [];
      final idx = hand.indexWhere((c) => c.id == cardId);
      if (idx == -1) return;
      final card = hand[idx];

      final result = PistiEngine.playCard(state: game, playerId: playerId, card: card);
      if (result == null) return;
      tx.update(ref, result.toMap());
    });
  }

  /// Faz B: masa toplanır (yakalayan oyuncuya), sıra ilerler. İstemci,
  /// oynanan kartın masada kısa süre görünmesi için bunu bir gecikmeyle
  /// çağırır.
  Future<void> collectPile(String gameId) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final game = PistiGameState.fromMap(gameId, snap.data()!);
      final result = PistiEngine.collectPile(state: game);
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
        final game = PistiGameState.fromMap(gameId, snap.data()!);
        if (!game.players.contains(playerId)) return;
        final result = PistiEngine.leavePlayer(state: game, playerId: playerId);
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
