import 'pisti_card.dart';

/// "Bilgisayara Karşı Oyna" modunda kullanılan Pişti oyun durumu. Tamamen
/// cihaz içinde tutulur; Firestore'a bağlı değildir.
class PistiGameState {
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

  /// 'playing' | 'finished'
  final String status;

  /// Tek kazanan yoksa (berabere) null.
  final String? winner;
  final List<String> winners;
  final Map<String, int> scores;
  final Map<String, PistiScoreDetail> scoreDetail;

  /// Bir yakalama olduğunda masadaki kartlar hemen toplanmaz; oyuncu attığı
  /// kartı kısa bir süre masada görsün diye bu alan doluyken yeni hamleye
  /// izin verilmez.
  final PendingCapture? pendingCapture;

  const PistiGameState({
    required this.players,
    required this.playerNames,
    required this.hands,
    required this.pile,
    required this.drawPile,
    required this.won,
    required this.pistiCount,
    required this.lastCapturer,
    required this.currentTurn,
    required this.status,
    required this.winner,
    required this.winners,
    required this.scores,
    required this.scoreDetail,
    required this.pendingCapture,
  });

  PistiCard? get topOfPile => pile.isNotEmpty ? pile.last : null;

  PistiGameState copyWith({
    Map<String, List<PistiCard>>? hands,
    List<PistiCard>? pile,
    List<PistiCard>? drawPile,
    Map<String, List<PistiCard>>? won,
    Map<String, int>? pistiCount,
    String? lastCapturer,
    String? currentTurn,
    String? status,
    String? winner,
    List<String>? winners,
    Map<String, int>? scores,
    Map<String, PistiScoreDetail>? scoreDetail,
    bool clearPendingCapture = false,
    PendingCapture? pendingCapture,
  }) {
    return PistiGameState(
      players: players,
      playerNames: playerNames,
      hands: hands ?? this.hands,
      pile: pile ?? this.pile,
      drawPile: drawPile ?? this.drawPile,
      won: won ?? this.won,
      pistiCount: pistiCount ?? this.pistiCount,
      lastCapturer: lastCapturer ?? this.lastCapturer,
      currentTurn: currentTurn ?? this.currentTurn,
      status: status ?? this.status,
      winner: winner ?? this.winner,
      winners: winners ?? this.winners,
      scores: scores ?? this.scores,
      scoreDetail: scoreDetail ?? this.scoreDetail,
      pendingCapture:
          clearPendingCapture ? null : (pendingCapture ?? this.pendingCapture),
    );
  }
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
}
