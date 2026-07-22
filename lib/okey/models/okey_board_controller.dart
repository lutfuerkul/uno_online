import 'package:flutter/foundation.dart';

import 'okey_game_state.dart';
import 'okey_tile.dart';

/// [OkeyOnlineProvider] (online) ve [OkeyLocalProvider] (bilgisayara karşı)
/// için ortak arayüz. Tahta ([OkeyBoardView]) her iki modu da tek bir yerden
/// sunar.
abstract class OkeyBoardController implements Listenable {
  OkeyGameState? get state;

  /// Bu cihazın oyuncu kimliği (online: rastgele oturum kimliği; yerel: "you").
  String get selfId;

  bool get isMyTurn;

  /// Sıradaki oyuncu bu turda çekti mi (bu cihaz için).
  bool get hasDrawn;

  /// Elimdeki taşlar — kullanıcının seçtiği diziliş sırasında.
  List<OkeyTile> get myHand;

  /// Sıra yönünde (soldan sağa) diğer oyuncular.
  List<String> get opponents;

  String opponentName(String id);
  int opponentTileCount(String id);

  /// Bir oyuncunun ıskarta yığınının en üstteki taşı (yoksa null).
  OkeyTile? topDiscardOf(String id);

  /// Solumdaki oyuncunun alabileceğim en üstteki ıskarta taşı (yoksa null).
  OkeyTile? get takeableDiscard;

  /// Kendi en son attığım (ıskartaya bıraktığım) taş (yoksa null).
  OkeyTile? get myLastDiscard;

  /// Solumdaki oyuncunun kimliği.
  String get leftPlayerId;

  Future<void> drawFromStack();
  Future<void> drawFromDiscard();
  Future<void> discard(OkeyTile tile);

  /// Elimi otomatik dizer: [byGroups] true ise sayıya (grup/set) göre, aksi
  /// halde renk+sıraya (seri) göre. Yalnızca görsel diziliştir.
  void arrangeHand({required bool byGroups});

  /// Sürükle-bırak: [draggedId] taşını [targetId] taşının olduğu yere taşır
  /// (elin görsel dizilişini değiştirir; oyun durumunu etkilemez).
  void moveTile(String draggedId, String targetId);

  /// Elimde el açmayı sağlayan bir atış var mı (kullanıcıya ipucu için).
  bool get canFinish;

  Future<void> leaveGame();
}
