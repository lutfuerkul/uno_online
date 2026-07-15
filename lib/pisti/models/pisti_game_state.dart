import 'pisti_card.dart';

/// Bir Pişti oyununun anlık durumu. Hem online (Firestore belgesi) hem de
/// bilgisayara karşı (yerel, cihaz içi) modda aynı motor ([PistiEngine])
/// tarafından üretilir/güncellenir.
class PistiGameState {
  /// Online modda oda kodu (Firestore belge kimliği); yerel modda sabit bir
  /// yer tutucudur.
  final String id;

  /// 'waiting' | 'playing' | 'finished'
  final String status;

  final List<String> players;
  final Map<String, String> playerNames;
  final Map<String, List<PistiCard>> hands;

  /// Masadaki kartlar (en sonuncusu = en üstteki / son atılan).
  final List<PistiCard> pile;
  final List<PistiCard> drawPile;

  /// Oyuncu kimliği -> o oyuncunun yakaladığı kartlar.
  final Map<String, List<PistiCard>> won;
  final Map<String, int> pistiCount;
  final String? lastCapturer;
  final String currentTurn;

  /// Tek kazanan yoksa (berabere) null.
  final String? winner;
  final List<String> winners;
  final Map<String, int> scores;
  final Map<String, PistiScoreDetail> scoreDetail;

  /// Bir yakalama olduğunda masadaki kartlar hemen toplanmaz; oyuncu attığı
  /// kartı kısa bir süre masada görsün diye bu alan doluyken yeni hamleye
  /// izin verilmez.
  final PendingCapture? pendingCapture;

  final PistiLastAction? lastAction;

  const PistiGameState({
    required this.id,
    required this.status,
    required this.players,
    required this.playerNames,
    required this.hands,
    required this.pile,
    required this.drawPile,
    required this.won,
    required this.pistiCount,
    required this.lastCapturer,
    required this.currentTurn,
    required this.winner,
    required this.winners,
    required this.scores,
    required this.scoreDetail,
    required this.pendingCapture,
    required this.lastAction,
  });

  PistiCard? get topOfPile => pile.isNotEmpty ? pile.last : null;

  PistiGameState copyWith({
    String? status,
    List<String>? players,
    Map<String, String>? playerNames,
    Map<String, List<PistiCard>>? hands,
    List<PistiCard>? pile,
    List<PistiCard>? drawPile,
    Map<String, List<PistiCard>>? won,
    Map<String, int>? pistiCount,
    String? lastCapturer,
    String? currentTurn,
    bool clearWinner = false,
    String? winner,
    List<String>? winners,
    Map<String, int>? scores,
    Map<String, PistiScoreDetail>? scoreDetail,
    bool clearPendingCapture = false,
    PendingCapture? pendingCapture,
    bool clearLastAction = false,
    PistiLastAction? lastAction,
  }) {
    return PistiGameState(
      id: id,
      status: status ?? this.status,
      players: players ?? this.players,
      playerNames: playerNames ?? this.playerNames,
      hands: hands ?? this.hands,
      pile: pile ?? this.pile,
      drawPile: drawPile ?? this.drawPile,
      won: won ?? this.won,
      pistiCount: pistiCount ?? this.pistiCount,
      lastCapturer: lastCapturer ?? this.lastCapturer,
      currentTurn: currentTurn ?? this.currentTurn,
      winner: clearWinner ? null : (winner ?? this.winner),
      winners: winners ?? this.winners,
      scores: scores ?? this.scores,
      scoreDetail: scoreDetail ?? this.scoreDetail,
      pendingCapture:
          clearPendingCapture ? null : (pendingCapture ?? this.pendingCapture),
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
    );
  }

  factory PistiGameState.fromMap(String id, Map<String, dynamic> map) {
    List<PistiCard> parseCards(dynamic list) => (list as List? ?? [])
        .map((e) => PistiCard.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    Map<String, List<PistiCard>> parseHandLike(dynamic raw) =>
        Map<String, dynamic>.from(raw as Map? ?? {})
            .map((k, v) => MapEntry(k, parseCards(v)));

    final scoreDetailRaw = Map<String, dynamic>.from(map['scoreDetail'] as Map? ?? {});

    return PistiGameState(
      id: id,
      status: map['status'] as String? ?? 'waiting',
      players: List<String>.from(map['players'] as List? ?? []),
      playerNames: Map<String, String>.from(map['playerNames'] as Map? ?? {}),
      hands: parseHandLike(map['hands']),
      pile: parseCards(map['pile']),
      drawPile: parseCards(map['drawPile']),
      won: parseHandLike(map['won']),
      pistiCount: Map<String, int>.from(map['pistiCount'] as Map? ?? {}),
      lastCapturer: map['lastCapturer'] as String?,
      currentTurn: map['currentTurn'] as String? ?? '',
      winner: map['winner'] as String?,
      winners: List<String>.from(map['winners'] as List? ?? []),
      scores: Map<String, int>.from(map['scores'] as Map? ?? {}),
      scoreDetail: scoreDetailRaw.map(
        (k, v) => MapEntry(k, PistiScoreDetail.fromMap(Map<String, dynamic>.from(v as Map))),
      ),
      pendingCapture: PendingCapture.fromMap(map['pendingCapture'] as Map?),
      lastAction: PistiLastAction.fromMap(map['lastAction'] as Map?),
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status,
        'players': players,
        'playerNames': playerNames,
        'hands': hands.map((k, v) => MapEntry(k, v.map((c) => c.toMap()).toList())),
        'pile': pile.map((c) => c.toMap()).toList(),
        'drawPile': drawPile.map((c) => c.toMap()).toList(),
        'won': won.map((k, v) => MapEntry(k, v.map((c) => c.toMap()).toList())),
        'pistiCount': pistiCount,
        'lastCapturer': lastCapturer,
        'currentTurn': currentTurn,
        'winner': winner,
        'winners': winners,
        'scores': scores,
        'scoreDetail': scoreDetail.map((k, v) => MapEntry(k, v.toMap())),
        'pendingCapture': pendingCapture?.toMap(),
        'lastAction': lastAction?.toMap(),
      };
}

class PendingCapture {
  final String by;
  final bool isPisti;
  final bool endsGame;

  const PendingCapture({
    required this.by,
    required this.isPisti,
    required this.endsGame,
  });

  Map<String, dynamic> toMap() => {'by': by, 'isPisti': isPisti, 'endsGame': endsGame};

  static PendingCapture? fromMap(Map? map) {
    if (map == null) return null;
    return PendingCapture(
      by: map['by'] as String? ?? '',
      isPisti: map['isPisti'] as bool? ?? false,
      endsGame: map['endsGame'] as bool? ?? false,
    );
  }
}

/// Son oynanan hamle; tahtada "Ali Karo 7 oynadı — yaktı! 🔥" gibi bir mesaj
/// göstermek için kullanılır.
class PistiLastAction {
  final String player;
  final PistiCard card;
  final bool captured;
  final bool isPisti;

  const PistiLastAction({
    required this.player,
    required this.card,
    required this.captured,
    required this.isPisti,
  });

  Map<String, dynamic> toMap() => {
        'player': player,
        'card': card.toMap(),
        'captured': captured,
        'isPisti': isPisti,
      };

  static PistiLastAction? fromMap(Map? map) {
    if (map == null) return null;
    final cardMap = map['card'] as Map?;
    if (cardMap == null) return null;
    return PistiLastAction(
      player: map['player'] as String? ?? '',
      card: PistiCard.fromMap(Map<String, dynamic>.from(cardMap)),
      captured: map['captured'] as bool? ?? false,
      isPisti: map['isPisti'] as bool? ?? false,
    );
  }
}

class PistiScoreDetail {
  final int cardCount;
  final int jackCount;
  final int aceCount;
  final int clubTwoCount;
  final int diamondTenCount;
  final bool mostCards;
  final int pisti;
  final int total;

  const PistiScoreDetail({
    required this.cardCount,
    required this.jackCount,
    required this.aceCount,
    required this.clubTwoCount,
    required this.diamondTenCount,
    required this.mostCards,
    required this.pisti,
    required this.total,
  });

  Map<String, dynamic> toMap() => {
        'cardCount': cardCount,
        'jackCount': jackCount,
        'aceCount': aceCount,
        'clubTwoCount': clubTwoCount,
        'diamondTenCount': diamondTenCount,
        'mostCards': mostCards,
        'pisti': pisti,
        'total': total,
      };

  factory PistiScoreDetail.fromMap(Map<String, dynamic> map) => PistiScoreDetail(
        cardCount: (map['cardCount'] as num?)?.toInt() ?? 0,
        jackCount: (map['jackCount'] as num?)?.toInt() ?? 0,
        aceCount: (map['aceCount'] as num?)?.toInt() ?? 0,
        clubTwoCount: (map['clubTwoCount'] as num?)?.toInt() ?? 0,
        diamondTenCount: (map['diamondTenCount'] as num?)?.toInt() ?? 0,
        mostCards: map['mostCards'] as bool? ?? false,
        pisti: (map['pisti'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
      );
}
