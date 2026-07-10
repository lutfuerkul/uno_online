import 'uno_card.dart';

/// Firestore'daki tek oyun belgesinin Dart karşılığı.
///
/// İki telefon da bu belgeyi canlı dinler; her değişiklik anında yansır.
class GameState {
  /// Oda kodu (belge kimliği), örn. "K7P2M".
  final String id;

  /// 'waiting' | 'playing' | 'finished'
  final String status;

  /// Oyuncu kimlikleri (en fazla 2).
  final List<String> players;

  /// Oyuncu kimliği -> görünen ad.
  final Map<String, String> playerNames;

  /// Oyuncu kimliği -> elindeki kartlar.
  final Map<String, List<UnoCard>> hands;

  /// Çekme destesi.
  final List<UnoCard> drawPile;

  /// Atılan deste (en üstteki = son oynanan kart).
  final List<UnoCard> discardPile;

  /// Geçerli renk (joker sonrası seçilen rengi de tutar).
  final CardColor currentColor;

  /// Sırası gelen oyuncunun kimliği.
  final String currentTurn;

  /// Kazanan oyuncunun kimliği (oyun bitmediyse null).
  final String? winner;

  const GameState({
    required this.id,
    required this.status,
    required this.players,
    required this.playerNames,
    required this.hands,
    required this.drawPile,
    required this.discardPile,
    required this.currentColor,
    required this.currentTurn,
    required this.winner,
  });

  /// Atılan destenin en üstündeki kart.
  UnoCard? get topCard => discardPile.isNotEmpty ? discardPile.last : null;

  factory GameState.fromMap(String id, Map<String, dynamic> map) {
    List<UnoCard> parseCards(dynamic list) => (list as List? ?? [])
        .map((e) => UnoCard.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    final handsRaw = Map<String, dynamic>.from(map['hands'] as Map? ?? {});

    return GameState(
      id: id,
      status: map['status'] as String? ?? 'waiting',
      players: List<String>.from(map['players'] as List? ?? []),
      playerNames: Map<String, String>.from(map['playerNames'] as Map? ?? {}),
      hands: handsRaw.map((k, v) => MapEntry(k, parseCards(v))),
      drawPile: parseCards(map['drawPile']),
      discardPile: parseCards(map['discardPile']),
      currentColor:
          CardColor.values.byName(map['currentColor'] as String? ?? 'red'),
      currentTurn: map['currentTurn'] as String? ?? '',
      winner: map['winner'] as String?,
    );
  }
}
