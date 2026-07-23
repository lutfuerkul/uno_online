import 'uno_card.dart';

/// Bir UNO oyununun anlık durumu. Hem online (Firestore belgesi) hem de
/// bilgisayara karşı (yerel, cihaz içi) modda aynı motor ([UnoEngine])
/// tarafından üretilir/güncellenir.
class GameState {
  /// Online modda oda kodu (Firestore belge kimliği); yerel modda sabit bir
  /// yer tutucudur.
  final String id;

  /// 'waiting' | 'playing' | 'finished'
  final String status;

  /// Oyuncu kimlikleri (en fazla 4), oturma sırasına göre.
  final List<String> players;

  /// Oyuncu kimliği -> görünen ad.
  final Map<String, String> playerNames;

  /// Oyuncu kimliği -> yüklediği profil fotoğrafı (base64 jpeg). Fotoğrafı
  /// olmayan oyuncular haritada yer almaz.
  final Map<String, String> playerPhotos;

  /// Oyuncu kimliği -> elindeki kartlar.
  final Map<String, List<UnoCard>> hands;

  final List<UnoCard> drawPile;

  /// Atılan deste (en üstteki = son oynanan kart).
  final List<UnoCard> discardPile;

  /// Geçerli renk (joker sonrası seçilen rengi de tutar).
  final CardColor currentColor;

  /// Sırası gelen oyuncunun kimliği.
  final String currentTurn;

  /// 1: normal sıra yönü, -1: ters (bu kural setinde reverse yön çevirmez,
  /// alan yalnızca şema/uyum için tutulur).
  final int direction;

  /// Bu turda zaten kart çekildi mi (çekilince sıra otomatik geçmez; oyuncu
  /// çektiği kartı oynayabilir ya da "Pas Geç" der).
  final bool hasDrawn;

  /// Reverse sonrası kilit: doluysa yalnızca bu renk / başka bir reverse /
  /// +2 / joker / +4 oynanabilir.
  final CardColor? reverseColor;

  /// Skip/+2/+4 ile "bloklanmış" (bir sonraki turu atlanacak) oyuncular
  /// kuyruğu. Birden fazla blok üst üste binebilir.
  final List<String> blockedPlayers;

  final String? winner;

  final UnoLastAction? lastAction;

  const GameState({
    required this.id,
    required this.status,
    required this.players,
    required this.playerNames,
    required this.playerPhotos,
    required this.hands,
    required this.drawPile,
    required this.discardPile,
    required this.currentColor,
    required this.currentTurn,
    required this.direction,
    required this.hasDrawn,
    required this.reverseColor,
    required this.blockedPlayers,
    required this.winner,
    required this.lastAction,
  });

  UnoCard? get topCard => discardPile.isNotEmpty ? discardPile.last : null;

  GameState copyWith({
    String? status,
    List<String>? players,
    Map<String, String>? playerNames,
    Map<String, String>? playerPhotos,
    Map<String, List<UnoCard>>? hands,
    List<UnoCard>? drawPile,
    List<UnoCard>? discardPile,
    CardColor? currentColor,
    String? currentTurn,
    int? direction,
    bool? hasDrawn,
    bool clearReverseColor = false,
    CardColor? reverseColor,
    List<String>? blockedPlayers,
    bool clearWinner = false,
    String? winner,
    bool clearLastAction = false,
    UnoLastAction? lastAction,
  }) {
    return GameState(
      id: id,
      status: status ?? this.status,
      players: players ?? this.players,
      playerNames: playerNames ?? this.playerNames,
      playerPhotos: playerPhotos ?? this.playerPhotos,
      hands: hands ?? this.hands,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      currentColor: currentColor ?? this.currentColor,
      currentTurn: currentTurn ?? this.currentTurn,
      direction: direction ?? this.direction,
      hasDrawn: hasDrawn ?? this.hasDrawn,
      reverseColor: clearReverseColor ? null : (reverseColor ?? this.reverseColor),
      blockedPlayers: blockedPlayers ?? this.blockedPlayers,
      winner: clearWinner ? null : (winner ?? this.winner),
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
    );
  }

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
      playerPhotos:
          Map<String, String>.from(map['playerPhotos'] as Map? ?? {}),
      hands: handsRaw.map((k, v) => MapEntry(k, parseCards(v))),
      drawPile: parseCards(map['drawPile']),
      discardPile: parseCards(map['discardPile']),
      currentColor:
          CardColor.values.byName(map['currentColor'] as String? ?? 'red'),
      currentTurn: map['currentTurn'] as String? ?? '',
      direction: (map['direction'] as num?)?.toInt() ?? 1,
      hasDrawn: map['hasDrawn'] as bool? ?? false,
      reverseColor: map['reverseColor'] != null
          ? CardColor.values.byName(map['reverseColor'] as String)
          : null,
      blockedPlayers: List<String>.from(map['blockedPlayers'] as List? ?? []),
      winner: map['winner'] as String?,
      lastAction: UnoLastAction.fromMap(map['lastAction'] as Map?),
    );
  }

  /// Firestore'a (ya da yerel motora) yazılacak alanlar. `id` dahil değildir
  /// (belge kimliği ayrı tutulur).
  Map<String, dynamic> toMap() => {
        'status': status,
        'players': players,
        'playerNames': playerNames,
        'playerPhotos': playerPhotos,
        'hands': hands.map((k, v) => MapEntry(k, v.map((c) => c.toMap()).toList())),
        'drawPile': drawPile.map((c) => c.toMap()).toList(),
        'discardPile': discardPile.map((c) => c.toMap()).toList(),
        'currentColor': currentColor.name,
        'currentTurn': currentTurn,
        'direction': direction,
        'hasDrawn': hasDrawn,
        'unoSafe': const <dynamic>[], // şema uyumu için (henüz kullanılmıyor)
        'reverseColor': reverseColor?.name,
        'blockedPlayers': blockedPlayers,
        'winner': winner,
        'lastAction': lastAction?.toMap(),
      };
}

/// Son hamlenin ne olduğunu tutar; tahtada "🚫 Ali → Veli bloklandı" gibi bir
/// mesaj göstermek için kullanılır.
class UnoLastAction {
  final String player;

  /// null ise bu hamle bir "pas geç"tir.
  final CardType? cardType;
  final CardColor? cardColor;
  final int? cardValue;
  final String? target;
  final bool isPass;

  const UnoLastAction({
    required this.player,
    this.cardType,
    this.cardColor,
    this.cardValue,
    this.target,
    this.isPass = false,
  });

  Map<String, dynamic> toMap() => {
        'player': player,
        'cardType': isPass ? 'pass' : cardType?.name,
        'cardColor': cardColor?.name,
        'cardValue': cardValue,
        'target': target,
      };

  static UnoLastAction? fromMap(Map? map) {
    if (map == null) return null;
    final typeStr = map['cardType'] as String?;
    if (typeStr == null) return null;
    if (typeStr == 'pass') {
      return UnoLastAction(player: map['player'] as String? ?? '', isPass: true);
    }
    return UnoLastAction(
      player: map['player'] as String? ?? '',
      cardType: CardType.values.byName(typeStr),
      cardColor:
          map['cardColor'] != null ? CardColor.values.byName(map['cardColor'] as String) : null,
      cardValue: (map['cardValue'] as num?)?.toInt(),
      target: map['target'] as String?,
    );
  }
}
