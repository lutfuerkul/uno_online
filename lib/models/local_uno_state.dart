import 'uno_card.dart';

/// "Bilgisayara Karşı Oyna" modunda kullanılan UNO oyun durumu.
///
/// Online [GameState]'den farkı: Firestore'a bağlı değildir, tamamen cihaz
/// içinde tutulur; 2'den fazla oyuncu (bot) ve sıra yönünü ([direction])
/// destekler.
class LocalUnoState {
  final List<String> players;
  final Map<String, String> playerNames;
  final Map<String, List<UnoCard>> hands;
  final List<UnoCard> drawPile;
  final List<UnoCard> discardPile;
  final CardColor currentColor;
  final String currentTurn;

  /// 1: normal sıra yönü, -1: ters.
  final int direction;

  /// 'playing' | 'finished'
  final String status;

  final String? winner;

  const LocalUnoState({
    required this.players,
    required this.playerNames,
    required this.hands,
    required this.drawPile,
    required this.discardPile,
    required this.currentColor,
    required this.currentTurn,
    required this.direction,
    required this.status,
    required this.winner,
  });

  UnoCard? get topCard => discardPile.isNotEmpty ? discardPile.last : null;

  LocalUnoState copyWith({
    Map<String, List<UnoCard>>? hands,
    List<UnoCard>? drawPile,
    List<UnoCard>? discardPile,
    CardColor? currentColor,
    String? currentTurn,
    int? direction,
    String? status,
    String? winner,
  }) {
    return LocalUnoState(
      players: players,
      playerNames: playerNames,
      hands: hands ?? this.hands,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      currentColor: currentColor ?? this.currentColor,
      currentTurn: currentTurn ?? this.currentTurn,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      winner: winner ?? this.winner,
    );
  }
}
