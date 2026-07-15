import '../models/game_state.dart';
import '../models/uno_card.dart';
import 'uno_engine.dart';

/// "Bilgisayara Karşı Oyna" modundaki bot oyuncuların hamle seçimini yapan
/// basit kural tabanlı yapay zeka. Web sürümündeki bot mantığıyla aynı
/// önceliklendirmeyi kullanır: rakip(ler)in eli azaldıkça saldırgan kartları
/// (skip/+2/+4) öne çıkarır, jokerleri mümkün olduğunca sona saklar.
class UnoBotService {
  /// [hand] içinde şu an oynanabilir kartları döndürür.
  static List<UnoCard> playable(List<UnoCard> hand, GameState state) {
    return hand.where((c) => UnoEngine.isPlayable(c, state)).toList();
  }

  /// Oynanabilir adaylar arasından en iyi kartı seçer.
  static UnoCard pickCard(
    List<UnoCard> candidates,
    GameState state,
    String botId,
  ) {
    final opponents = state.players.where((p) => p != botId).toList();
    final threat = opponents
        .map((p) => state.hands[p]?.length ?? 0)
        .reduce((a, b) => a < b ? a : b);

    int score(UnoCard c) {
      switch (c.type) {
        case CardType.number:
          return 1;
        case CardType.reverse:
          return 2;
        case CardType.skip:
        case CardType.drawTwo:
          return threat <= 2 ? 5 : 2;
        case CardType.wildDrawFour:
          return threat <= 2 ? 4 : 0; // baskı yokken +4'ü sakla
        case CardType.wild:
          return 0; // jokeri sakla
      }
    }

    final sorted = [...candidates]
      ..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.first;
  }

  /// Joker sonrası seçilecek renk: elde en çok bulunan renk.
  static CardColor pickColor(List<UnoCard> hand) {
    final counts = <CardColor, int>{
      CardColor.red: 0,
      CardColor.yellow: 0,
      CardColor.green: 0,
      CardColor.blue: 0,
    };
    for (final c in hand) {
      if (c.color != CardColor.wild) {
        counts[c.color] = (counts[c.color] ?? 0) + 1;
      }
    }
    var best = CardColor.red;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        bestCount = entry.value;
        best = entry.key;
      }
    }
    return best;
  }

  /// Skip/+2/+4 için hedef oyuncu: kazanmaya en yakın (en az kartlı) rakip.
  static String pickTarget(GameState state, String botId) {
    final opponents = state.players.where((p) => p != botId).toList()
      ..sort((a, b) => (state.hands[a]?.length ?? 0).compareTo(state.hands[b]?.length ?? 0));
    return opponents.first;
  }
}
