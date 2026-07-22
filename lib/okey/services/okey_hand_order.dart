import '../models/okey_tile.dart';

/// El dizilişi yardımcıları. Diziliş yalnızca görseldir (oyun durumunu
/// değiştirmez); her sağlayıcı, taş kimliklerinin sırasını yerelde tutar.
class OkeyHandOrder {
  /// [hand]'i [order]'daki kimlik sırasına göre dizer. [order]'da olmayan
  /// (yeni çekilen) taşlar sona eklenir; [order]'da olup elde olmayan
  /// kimlikler yok sayılır.
  static List<OkeyTile> apply(List<OkeyTile> hand, List<String> order) {
    if (order.isEmpty) return List<OkeyTile>.of(hand);
    final byId = {for (final t in hand) t.id: t};
    final result = <OkeyTile>[];
    final used = <String>{};
    for (final id in order) {
      final tile = byId[id];
      if (tile != null && used.add(id)) result.add(tile);
    }
    for (final t in hand) {
      if (!used.contains(t.id)) result.add(t);
    }
    return result;
  }

  /// Otomatik diziliş için taş kimlik sırası üretir.
  ///  - [byGroups] false: renk sonra sayı (serileri yan yana getirir).
  ///  - [byGroups] true: sayı sonra renk (grupları/setleri yan yana getirir).
  /// Sahte okey/joker taşlar en sona konur.
  static List<String> sorted(
    List<OkeyTile> hand, {
    required bool byGroups,
    required bool Function(OkeyTile) isOkey,
  }) {
    final tiles = List<OkeyTile>.of(hand);
    tiles.sort((a, b) {
      final aw = isOkey(a) || a.isFakeJoker;
      final bw = isOkey(b) || b.isFakeJoker;
      if (aw != bw) return aw ? 1 : -1; // jokerler sona
      if (aw && bw) return 0;
      if (byGroups) {
        if (a.number != b.number) return a.number.compareTo(b.number);
        return a.color.index.compareTo(b.color.index);
      } else {
        if (a.color.index != b.color.index) {
          return a.color.index.compareTo(b.color.index);
        }
        return a.number.compareTo(b.number);
      }
    });
    return [for (final t in tiles) t.id];
  }
}

/// Istaka yuva düzeni yardımcıları. Yuva listesi (`List<String?>`) her elemanı
/// bir taş kimliği ya da boş yuva (null) olan görsel düzeni tutar; boşluk
/// bırakmaya ve serbest yerleşime izin verir.
class OkeySlots {
  /// [slots]'u güncel el ([handIds]) ile eşitler: elde olmayan (atılan) taşlar
  /// yuvadan çıkarılır (yeri boş kalır); yuvada olmayan yeni taşlar ilk boş
  /// yuvaya, yoksa sona eklenir. Yeni bir liste döndürür.
  static List<String?> sync(List<String?> slots, List<String> handIds) {
    final handSet = handIds.toSet();
    final out = List<String?>.from(slots);
    for (var i = 0; i < out.length; i++) {
      if (out[i] != null && !handSet.contains(out[i])) out[i] = null;
    }
    final present = out.whereType<String>().toSet();
    for (final id in handIds) {
      if (present.contains(id)) continue;
      final empty = out.indexOf(null);
      if (empty >= 0) {
        out[empty] = id;
      } else {
        out.add(id);
      }
      present.add(id);
    }
    return out;
  }

  /// [tileId] taşını [slotIndex] yuvasına koyar. Hedef doluysa yer değiştirir,
  /// boşsa taşın eski yeri boş kalır. Önce [handIds] ile eşitlenir.
  static List<String?> place(
    List<String?> slots,
    List<String> handIds,
    String tileId,
    int slotIndex,
  ) {
    final out = sync(slots, handIds);
    if (slotIndex < 0) return out;
    if (slotIndex >= out.length) {
      out.addAll(List<String?>.filled(slotIndex - out.length + 1, null));
    }
    final from = out.indexOf(tileId);
    if (from == -1 || from == slotIndex) return out;
    out[from] = out[slotIndex];
    out[slotIndex] = tileId;
    return out;
  }
}
