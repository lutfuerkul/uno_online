import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncunun profil fotoğrafını (base64 jpeg, küçük thumbnail) cihazda
/// saklar — [PlayerNameStore] ile aynı desende, üç oyun için de ayrı anahtar.
class PlayerPhotoStore {
  static const String unoKey = 'uno_photo';
  static const String pistiKey = 'pisti_photo';
  static const String okeyKey = 'okey_photo';

  static Future<String?> loadUnoPhoto() => _load(unoKey);
  static Future<String?> loadPistiPhoto() => _load(pistiKey);
  static Future<String?> loadOkeyPhoto() => _load(okeyKey);

  static Future<void> saveUnoPhoto(String? base64Jpeg) => _save(unoKey, base64Jpeg);
  static Future<void> savePistiPhoto(String? base64Jpeg) => _save(pistiKey, base64Jpeg);
  static Future<void> saveOkeyPhoto(String? base64Jpeg) => _save(okeyKey, base64Jpeg);

  static Future<String?> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(key);
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> _save(String key, String? base64Jpeg) async {
    final prefs = await SharedPreferences.getInstance();
    if (base64Jpeg == null || base64Jpeg.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, base64Jpeg);
    }
  }
}
