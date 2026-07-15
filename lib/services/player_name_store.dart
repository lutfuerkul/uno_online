import 'package:shared_preferences/shared_preferences.dart';

/// Oyuncu adını cihazda saklar — web sürümündeki `localStorage` (`uno_name`,
/// `pisti_name`) ile aynı anahtarları kullanır.
class PlayerNameStore {
  static const String unoKey = 'uno_name';
  static const String pistiKey = 'pisti_name';
  static const int maxLength = 12;

  static Future<String> loadUnoName() => _load(unoKey);
  static Future<String> loadPistiName() => _load(pistiKey);

  static Future<void> saveUnoName(String name) => _save(unoKey, name);
  static Future<void> savePistiName(String name) => _save(pistiKey, name);

  static Future<String> _load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return normalize(prefs.getString(key) ?? '');
  }

  static Future<void> _save(String key, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = normalize(name);
    if (normalized.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, normalized);
    }
  }

  static String normalize(String name) {
    final trimmed = name.trim();
    if (trimmed.length > maxLength) {
      return trimmed.substring(0, maxLength);
    }
    return trimmed;
  }
}
