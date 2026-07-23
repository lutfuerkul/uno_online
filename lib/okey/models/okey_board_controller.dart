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

  /// Elimdeki taşlar — yuva sırasına göre (boşluklar atlanmış, sıkıştırılmış).
  List<OkeyTile> get myHand;

  /// Istakadaki yuva düzeni: her eleman bir taş kimliği ya da boş yuva (null).
  /// Serbest yerleşim/boşluk bırakma için kullanılır.
  List<String?> get handSlots;

  /// Sıra yönünde (soldan sağa) diğer oyuncular.
  List<String> get opponents;

  String opponentName(String id);
  int opponentTileCount(String id);

  /// Oyuncunun yüklediği profil fotoğrafı (base64 jpeg), yoksa null.
  String? opponentPhoto(String id);

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

  /// Normal atış ("Attığım" alanına bırakılınca). Eli otomatik bitirmez;
  /// sıra bir sonrakine geçer.
  Future<void> discard(OkeyTile tile);

  /// Eli bitirme atışı (göstergenin üzerine bırakılınca). Kalan taşlar
  /// geçerli gruplara bölünmüyorsa hiçbir şey yapmaz (taş elde kalır).
  Future<void> finishDiscard(OkeyTile tile);

  /// Elimi otomatik dizer: [byGroups] true ise sayıya (grup/set) göre, aksi
  /// halde renk+sıraya (seri) göre. Yalnızca görsel diziliştir.
  void arrangeHand({required bool byGroups});

  /// Sürükle-bırak: [tileId] taşını [slotIndex] yuvasına koyar. Hedef yuva
  /// boşsa taş oraya gider ve eski yeri boş kalır (boşluk); doluysa oradaki
  /// taşla yer değiştirir. Yalnızca görsel dizilişi değiştirir.
  void placeTile(String tileId, int slotIndex);

  /// Elimde el açmayı sağlayan bir atış var mı (kullanıcıya ipucu için).
  bool get canFinish;

  Future<void> leaveGame();
}
