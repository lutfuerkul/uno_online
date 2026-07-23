import 'okey_tile.dart';

/// Bir Okey elinin anlık durumu. Hem online (Firestore belgesi) hem de
/// bilgisayara karşı (yerel) modda aynı motor ([OkeyEngine]) tarafından
/// üretilir/güncellenir.
class OkeyGameState {
  /// Online modda oda kodu (Firestore belge kimliği); yerelde 'local'.
  final String id;

  /// 'waiting' | 'playing' | 'finished'
  final String status;

  final List<String> players;
  final Map<String, String> playerNames;

  /// Oyuncuların yüklediği profil fotoğrafları (base64 jpeg). Fotoğrafı
  /// olmayan oyuncular haritada yer almaz.
  final Map<String, String> playerPhotos;
  final Map<String, List<OkeyTile>> hands;

  /// Ortadaki kapalı taş yığını (deste). Son eleman = en üstteki çekilecek taş.
  final List<OkeyTile> drawPile;

  /// Her oyuncunun sağına attığı taşlar (kendi ıskarta yığını). Son eleman =
  /// en üstteki. Bir sonraki oyuncu yalnızca solundaki oyuncunun en üstteki
  /// ıskartasını alabilir.
  final Map<String, List<OkeyTile>> discards;

  /// Göstergedeki taş. Okey (joker) = göstergeyle aynı renkte, bir büyük sayı.
  final OkeyTile indicator;

  final String currentTurn;

  /// Sıradaki oyuncu bu turda taş çekti mi? Çekmeden atamaz.
  final bool hasDrawn;

  /// Bu turda soldaki ıskartadan alınan taşın kimliği (varsa). Aynı turda
  /// alınan taş geri atılamaz.
  final String? drawnFromDiscardId;

  final OkeyLastAction? lastAction;

  /// Tek kazanan (el açan). Berabere (taş bitti) ise null.
  final String? winner;
  final List<String> winners;

  /// El okey (joker) atılarak bitirildiyse çifte puan.
  final bool finishedByOkey;

  /// Bu elin puanları (yalnızca bu el için — bitiş ekranındaki "+N puan"
  /// mesajı bunu kullanır).
  final Map<String, int> scores;

  /// Oyundan çıkılmadıkça (yeniden başlatılsa/rövanş yapılsa da) birikerek
  /// güncel tutulan toplam puan tablosu.
  final Map<String, int> cumulativeScores;

  const OkeyGameState({
    required this.id,
    required this.status,
    required this.players,
    required this.playerNames,
    required this.playerPhotos,
    required this.hands,
    required this.drawPile,
    required this.discards,
    required this.indicator,
    required this.currentTurn,
    required this.hasDrawn,
    required this.drawnFromDiscardId,
    required this.lastAction,
    required this.winner,
    required this.winners,
    required this.finishedByOkey,
    required this.scores,
    required this.cumulativeScores,
  });

  /// Okey (joker) sayısı: göstergenin bir büyüğü (13'ten sonra 1'e döner).
  int get okeyNumber => indicator.number == 13 ? 1 : indicator.number + 1;
  OkeyColor get okeyColor => indicator.color;

  /// Taş bu elde okey (joker) mi? Sahte okeyler her zaman joker; ayrıca
  /// göstergeyle aynı renkte, bir büyük sayıdaki iki gerçek taş da jokerdir.
  bool isOkey(OkeyTile tile) {
    if (tile.isFakeJoker) return true;
    return tile.color == okeyColor && tile.number == okeyNumber;
  }

  OkeyGameState copyWith({
    String? status,
    List<String>? players,
    Map<String, String>? playerNames,
    Map<String, String>? playerPhotos,
    Map<String, List<OkeyTile>>? hands,
    List<OkeyTile>? drawPile,
    Map<String, List<OkeyTile>>? discards,
    OkeyTile? indicator,
    String? currentTurn,
    bool? hasDrawn,
    bool clearDrawnFromDiscard = false,
    String? drawnFromDiscardId,
    bool clearLastAction = false,
    OkeyLastAction? lastAction,
    bool clearWinner = false,
    String? winner,
    List<String>? winners,
    bool? finishedByOkey,
    Map<String, int>? scores,
    Map<String, int>? cumulativeScores,
  }) {
    return OkeyGameState(
      id: id,
      status: status ?? this.status,
      players: players ?? this.players,
      playerNames: playerNames ?? this.playerNames,
      playerPhotos: playerPhotos ?? this.playerPhotos,
      hands: hands ?? this.hands,
      drawPile: drawPile ?? this.drawPile,
      discards: discards ?? this.discards,
      indicator: indicator ?? this.indicator,
      currentTurn: currentTurn ?? this.currentTurn,
      hasDrawn: hasDrawn ?? this.hasDrawn,
      drawnFromDiscardId: clearDrawnFromDiscard
          ? null
          : (drawnFromDiscardId ?? this.drawnFromDiscardId),
      lastAction: clearLastAction ? null : (lastAction ?? this.lastAction),
      winner: clearWinner ? null : (winner ?? this.winner),
      winners: winners ?? this.winners,
      finishedByOkey: finishedByOkey ?? this.finishedByOkey,
      scores: scores ?? this.scores,
      cumulativeScores: cumulativeScores ?? this.cumulativeScores,
    );
  }

  factory OkeyGameState.fromMap(String id, Map<String, dynamic> map) {
    List<OkeyTile> parseTiles(dynamic list) => (list as List? ?? [])
        .map((e) => OkeyTile.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    Map<String, List<OkeyTile>> parseTileMap(dynamic raw) =>
        Map<String, dynamic>.from(raw as Map? ?? {})
            .map((k, v) => MapEntry(k, parseTiles(v)));

    final indMap = map['indicator'] as Map?;

    return OkeyGameState(
      id: id,
      status: map['status'] as String? ?? 'waiting',
      players: List<String>.from(map['players'] as List? ?? []),
      playerNames: Map<String, String>.from(map['playerNames'] as Map? ?? {}),
      playerPhotos:
          Map<String, String>.from(map['playerPhotos'] as Map? ?? {}),
      hands: parseTileMap(map['hands']),
      drawPile: parseTiles(map['drawPile']),
      discards: parseTileMap(map['discards']),
      indicator: indMap != null
          ? OkeyTile.fromMap(Map<String, dynamic>.from(indMap))
          : const OkeyTile(
              color: OkeyColor.yellow, number: 1, isFakeJoker: false, id: '_'),
      currentTurn: map['currentTurn'] as String? ?? '',
      hasDrawn: map['hasDrawn'] as bool? ?? false,
      drawnFromDiscardId: map['drawnFromDiscardId'] as String?,
      lastAction: OkeyLastAction.fromMap(map['lastAction'] as Map?),
      winner: map['winner'] as String?,
      winners: List<String>.from(map['winners'] as List? ?? []),
      finishedByOkey: map['finishedByOkey'] as bool? ?? false,
      scores: Map<String, int>.from(map['scores'] as Map? ?? {}),
      cumulativeScores:
          Map<String, int>.from(map['cumulativeScores'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'status': status,
        'players': players,
        'playerNames': playerNames,
        'playerPhotos': playerPhotos,
        'hands':
            hands.map((k, v) => MapEntry(k, v.map((t) => t.toMap()).toList())),
        'drawPile': drawPile.map((t) => t.toMap()).toList(),
        'discards': discards
            .map((k, v) => MapEntry(k, v.map((t) => t.toMap()).toList())),
        'indicator': indicator.toMap(),
        'currentTurn': currentTurn,
        'hasDrawn': hasDrawn,
        'drawnFromDiscardId': drawnFromDiscardId,
        'lastAction': lastAction?.toMap(),
        'winner': winner,
        'winners': winners,
        'finishedByOkey': finishedByOkey,
        'scores': scores,
        'cumulativeScores': cumulativeScores,
      };
}

/// Son oynanan hamle; tahtada "Ali sarı 7 attı" gibi bir mesaj göstermek için.
class OkeyLastAction {
  final String player;

  /// 'draw' | 'discard'
  final String type;

  /// Çekme, soldaki ıskartadan mı yapıldı?
  final bool fromDiscard;

  /// Atılan taş (type == 'discard' için).
  final OkeyTile? tile;

  const OkeyLastAction({
    required this.player,
    required this.type,
    required this.fromDiscard,
    required this.tile,
  });

  Map<String, dynamic> toMap() => {
        'player': player,
        'type': type,
        'fromDiscard': fromDiscard,
        'tile': tile?.toMap(),
      };

  static OkeyLastAction? fromMap(Map? map) {
    if (map == null) return null;
    final tileMap = map['tile'] as Map?;
    return OkeyLastAction(
      player: map['player'] as String? ?? '',
      type: map['type'] as String? ?? 'discard',
      fromDiscard: map['fromDiscard'] as bool? ?? false,
      tile: tileMap != null
          ? OkeyTile.fromMap(Map<String, dynamic>.from(tileMap))
          : null,
    );
  }
}
