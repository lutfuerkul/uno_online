import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncunun Okey profil fotoğrafını (base64 jpeg, küçük thumbnail) cihazda
/// saklar — [PlayerNameStore] ile aynı desende.
class PlayerPhotoStore {
  static const String okeyKey = 'okey_photo';

  static Future<String?> loadOkeyPhoto() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(okeyKey);
    return (value == null || value.isEmpty) ? null : value;
  }

  static Future<void> saveOkeyPhoto(String? base64Jpeg) async {
    final prefs = await SharedPreferences.getInstance();
    if (base64Jpeg == null || base64Jpeg.isEmpty) {
      await prefs.remove(okeyKey);
    } else {
      await prefs.setString(okeyKey, base64Jpeg);
    }
  }
}
