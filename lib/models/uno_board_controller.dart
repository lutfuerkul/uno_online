import 'package:flutter/foundation.dart';

import 'game_state.dart';
import 'uno_card.dart';

/// [GameProvider] (online) ve [LocalUnoProvider] (bilgisayara karşı) için
/// ortak arayüz. Web sürümü online/yerel modda aynı `renderBoard()` render
/// fonksiyonunu kullanır; bu arayüz Flutter tarafında aynı tahtayı
/// ([UnoBoardView]) her iki moda da tek bir yerden sunmayı sağlar.
abstract class UnoBoardController implements Listenable {
  GameState? get state;

  /// Bu cihazın oyuncu kimliği (online: rastgele oturum kimliği; yerel: "you").
  String get selfId;

  bool get isMyTurn;
  bool get hasDrawn;
  CardColor? get reverseColor;
  List<UnoCard> get myHand;
  bool get iWon;

  /// Sıra yönünde (soldan sağa) diğer oyuncular.
  List<String> get opponents;

  String opponentName(String id);
  int opponentCardCount(String id);
  int blockedCount(String id);

  bool canPlay(UnoCard card);

  Future<void> playCard(UnoCard card, {CardColor? chosenColor, String? targetId});
  Future<void> drawCard();
  Future<void> pass();
  Future<void> leaveGame();
}
