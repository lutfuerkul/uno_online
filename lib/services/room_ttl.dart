import 'package:cloud_firestore/cloud_firestore.dart';

/// Oda belgelerinin Firestore TTL ile otomatik silinmesi için `expireAt`.
///
/// Firebase Console'da her koleksiyon (`games`, `pisti_games`, `okey_games`)
/// için TTL politikası `expireAt` alanına bağlanmalıdır (bkz. docs/YAYIN.md).
class RoomTtl {
  /// Bekleme odası / terk edilmiş lobi.
  static const Duration waiting = Duration(hours: 24);

  /// Aktif oyun (her yazmada yenilenir).
  static const Duration active = Duration(days: 2);

  /// Biten oyun (rövanş beklenmezse).
  static const Duration finished = Duration(hours: 12);

  static Timestamp forStatus(String status) {
    final ttl = switch (status) {
      'waiting' => waiting,
      'finished' => finished,
      _ => active,
    };
    return Timestamp.fromDate(DateTime.now().add(ttl));
  }

  /// Mevcut yazma map'ine `expireAt` ekler; status map'ten veya [status]'ten okunur.
  static Map<String, dynamic> withExpire(
    Map<String, dynamic> data, {
    String? status,
  }) {
    final s = status ?? data['status'] as String? ?? 'playing';
    return {...data, 'expireAt': forStatus(s)};
  }
}
