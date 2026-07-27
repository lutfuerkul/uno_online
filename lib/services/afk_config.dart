/// Online AFK tur zaman aşımı ayarları.
///
/// Sırası gelen oyuncu [timeout] boyunca hamle yapmazsa otomatik hamle
/// uygulanır. Aynı oyuncu [kickAfterStrikes]. kez AFK olursa masadan atılır
/// (1. ve 2. → auto hamle, 3. → kick).
class AfkConfig {
  static const Duration timeout = Duration(seconds: 60);

  /// Kick için gereken AFK sayısı (3. timeout = kick).
  static const int kickAfterStrikes = 3;

  static int get timeoutMs => timeout.inMilliseconds;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// [turnStartedAt] üzerinden kalan süre; ≤0 ise süre dolmuş.
  static int remainingMs(int turnStartedAt, {int? now}) {
    final n = now ?? nowMs();
    final start = turnStartedAt <= 0 ? n : turnStartedAt;
    return start + timeoutMs - n;
  }

  static bool isExpired(int turnStartedAt, {int? now}) =>
      remainingMs(turnStartedAt, now: now) <= 0;

  static Map<String, int> parseStrikes(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map? ?? {});
    return map.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0));
  }

  static Map<String, int> resetStrike(Map<String, int> strikes, String playerId) {
    final out = Map<String, int>.from(strikes);
    out[playerId] = 0;
    return out;
  }

  static Map<String, int> bumpStrike(Map<String, int> strikes, String playerId) {
    final out = Map<String, int>.from(strikes);
    out[playerId] = (out[playerId] ?? 0) + 1;
    return out;
  }
}
