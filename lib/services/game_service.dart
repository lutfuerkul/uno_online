import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/game_state.dart';
import '../models/uno_card.dart';
import 'uno_engine.dart';

/// Firestore ile tüm oyun iletişimini yürütür: oda kurma, katılma, kurucunun
/// başlatması, kart oynama, kart çekme/pas ve oyunu canlı dinleme. Kurallar
/// [UnoEngine] üzerinden yürütülür; bu sınıf yalnızca okuma/yazma/eşzamanlılık
/// (transaction) ile ilgilenir.
class GameService {
  // Getter (final alan değil): Firebase henüz initializeApp() ile
  // başlatılmadıysa GameService()'in kendisi değil, yalnızca gerçekten bir
  // Firestore işlemi (kur/katıl/oyna...) yapılmaya çalışıldığında hata
  // fırlatsın diye. Aksi halde GameProvider oluşturulur oluşturulmaz (UNO'ya
  // dokunur dokunmaz, bilgisayara karşı moda bile geçmeden) çöküyordu.
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

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
      'drawPile': <dynamic>[],
      'discardPile': <dynamic>[],
      'currentColor': CardColor.red.name,
      'currentTurn': '',
      'direction': 1,
      'hasDrawn': false,
      'unoSafe': <dynamic>[],
      'reverseColor': null,
      'blockedPlayers': <dynamic>[],
      'winner': null,
      'lastAction': null,
      // Firestore güvenlik kuralları bunun bir sayı olmasını bekliyor (web
      // sürümündeki Date.now() ile eşleşsin diye FieldValue.serverTimestamp()
      // yerine epoch milisaniye kullanılır).
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return code;
  }

  /// Var olan odaya katılır. Oyuncu zaten listedeyse (kopup geri gelme)
  /// status ne olursa olsun kabul edilir; yeni katılım yalnızca `waiting`'de.
  Future<void> joinGame(String gameId, String playerId, String name,
      {String? photo}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw Exception('Oyun bulunamadı: $gameId');
      }
      final data = snap.data()!;
      final players = List<String>.from(data['players'] as List? ?? []);
      final names = Map<String, dynamic>.from(data['playerNames'] as Map? ?? {});
      final photos =
          Map<String, dynamic>.from(data['playerPhotos'] as Map? ?? {});

      // Rejoin: UID hâlâ odadaysa (uygulama kapanması leave çağırmaz) sadece
      // dinlemeye devam edilir — "oyun başladı" engeli uygulanmaz.
      if (players.contains(playerId)) return;

      if (data['status'] != 'waiting') {
        throw Exception('Oyun çoktan başladı.');
      }
      if (players.length >= UnoEngine.maxPlayers) {
        throw Exception('Oda dolu (en fazla ${UnoEngine.maxPlayers} kişi).');
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

  /// Yalnızca kurucu, en az 2 oyuncu varken oyunu başlatır.
  Future<void> startGame({required String gameId, required String playerId}) async {
    final ref = _games.doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] != 'waiting') return;
      final players = List<String>.from(data['players'] as List? ?? []);
      if (players.isEmpty || players.first != playerId) return; // sadece kurucu
      if (players.length < 2) return;

      final names = Map<String, String>.from(
        (data['playerNames'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final photos = Map<String, String>.from(
        (data['playerPhotos'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final fresh = UnoEngine.dealNewGame(
        id: gameId,
        players: players,
        playerNames: names,
        playerPhotos: photos,
      );
      tx.update(ref, fresh.toMap());
    });
  }

  /// Oyun belgesini canlı dinler.
  Stream<GameState?> watchGame(String gameId) {
    return _games.doc(gameId).snapshots().map(
          (snap) => snap.exists ? GameState.fromMap(gameId, snap.data()!) : null,
        );
  }

  /// Sırası gelen oyuncu bir kart oynar. Joker ise [chosenColor], skip/+2/+4
  /// ise (birden fazla rakip varsa) [targetId] verilebilir.
  /// Yazılan durumu döndürür — provider optimistic UI'ı doğrulasın diye.
  Future<GameState?> playCard({
    required String gameId,
    required String playerId,
    required String cardId,
    CardColor? chosenColor,
    String? targetId,
  }) {
    return _mutate(gameId, (game) {
      final hand = game.hands[playerId] ?? const [];
      final idx = hand.indexWhere((c) => c.id == cardId);
      if (idx == -1) return null;
      return UnoEngine.playCard(
        state: game,
        playerId: playerId,
        card: hand[idx],
        chosenColor: chosenColor,
        targetId: targetId,
      );
    });
  }

  /// Desteden 1 kart çeker. Sıra geçmez.
  Future<GameState?> drawCard(
      {required String gameId, required String playerId}) {
    return _mutate(gameId,
        (game) => UnoEngine.drawCard(state: game, playerId: playerId));
  }

  /// Kart çektikten sonra oynamak istemeyince sırayı sonraki oyuncuya bırakır.
  Future<GameState?> pass(
      {required String gameId, required String playerId}) {
    return _mutate(
        gameId, (game) => UnoEngine.pass(state: game, playerId: playerId));
  }

  Future<GameState?> _mutate(
    String gameId,
    GameState? Function(GameState game) apply,
  ) {
    final ref = _games.doc(gameId);
    return _db.runTransaction<GameState?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;
      final game = GameState.fromMap(gameId, snap.data()!);
      final result = apply(game);
      if (result == null) return null;
      tx.update(ref, result.toMap());
      return result;
    });
  }

  /// Oyuncuyu odadan çıkarır (diğerleri devam edebilsin diye durumu düzeltir).
  Future<void> leaveRoom({required String gameId, required String playerId}) async {
    final ref = _games.doc(gameId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final game = GameState.fromMap(gameId, snap.data()!);
        if (!game.players.contains(playerId)) return;
        final result = UnoEngine.leavePlayer(state: game, playerId: playerId);
        tx.update(ref, result.toMap());
      });
    } catch (_) {
      // hata olsa da yerelden çık
    }
  }

  /// Oyunu aynı oyuncularla yeniden başlatmak için bekleme odasına döndürür.
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
        'discardPile': <dynamic>[],
        'currentColor': CardColor.red.name,
        'currentTurn': '',
        'direction': 1,
        'hasDrawn': false,
        'unoSafe': <dynamic>[],
        'reverseColor': null,
        'blockedPlayers': <dynamic>[],
        'winner': null,
        'lastAction': null,
      });
    });
  }

  /// Karışması zor karakterlerle 5 haneli oda kodu üretir.
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
