import 'package:flutter/foundation.dart';

import 'pisti_card.dart';
import 'pisti_game_state.dart';

/// [PistiOnlineProvider] (online) ve [PistiLocalProvider] (bilgisayara karşı)
/// için ortak arayüz. Web sürümü online/yerel modda aynı `renderBoard()`
/// render fonksiyonunu kullanır; bu arayüz Flutter tarafında aynı tahtayı
/// ([PistiBoardView]) her iki moda da tek bir yerden sunmayı sağlar.
abstract class PistiBoardController implements Listenable {
  PistiGameState? get state;

  /// Bu cihazın oyuncu kimliği (online: rastgele oturum kimliği; yerel: "you").
  String get selfId;

  bool get isMyTurn;
  List<PistiCard> get myHand;

  /// Sıra yönünde (soldan sağa) diğer oyuncular.
  List<String> get opponents;

  String opponentName(String id);
  int opponentCardCount(String id);
  int wonCount(String id);
  int pistiCountFor(String id);

  /// Oyuncunun yüklediği profil fotoğrafı (base64 jpeg), yoksa null.
  String? opponentPhoto(String id);

  Future<void> playCard(PistiCard card);
  Future<void> leaveGame();
}
