import 'package:uuid/uuid.dart';

import '../models/uno_card.dart';

/// Standart 108 kartlık UNO destesini üretir ve kart oynama kurallarını
/// içerir.
class DeckService {
  static const _uuid = Uuid();

  /// 108 kartlık tam UNO destesini oluşturur (karılmamış).
  ///
  /// Her renk için: bir adet 0, ikişer adet 1-9, ikişer adet Skip/Reverse/+2.
  /// Ayrıca 4 Joker ve 4 adet +4 Joker.
  static List<UnoCard> buildDeck() {
    final deck = <UnoCard>[];
    const colors = [
      CardColor.red,
      CardColor.yellow,
      CardColor.green,
      CardColor.blue,
    ];

    for (final color in colors) {
      // Bir tane 0.
      deck.add(UnoCard(
        color: color,
        type: CardType.number,
        value: 0,
        id: _uuid.v4(),
      ));
      // 1-9 arası ikişer tane.
      for (var n = 1; n <= 9; n++) {
        for (var i = 0; i < 2; i++) {
          deck.add(UnoCard(
            color: color,
            type: CardType.number,
            value: n,
            id: _uuid.v4(),
          ));
        }
      }
      // Aksiyon kartları: ikişer tane.
      for (final type in [CardType.skip, CardType.reverse, CardType.drawTwo]) {
        for (var i = 0; i < 2; i++) {
          deck.add(UnoCard(color: color, type: type, id: _uuid.v4()));
        }
      }
    }

    // Joker kartlar: 4 Joker + 4 tane +4.
    for (var i = 0; i < 4; i++) {
      deck.add(UnoCard(
        color: CardColor.wild,
        type: CardType.wild,
        id: _uuid.v4(),
      ));
      deck.add(UnoCard(
        color: CardColor.wild,
        type: CardType.wildDrawFour,
        id: _uuid.v4(),
      ));
    }

    return deck;
  }

  /// [card] kartı, atılan destenin en üstündeki [top] karta ve geçerli renge
  /// ([currentColor]) göre oynanabilir mi?
  static bool canPlay(UnoCard card, UnoCard top, CardColor currentColor) {
    // Jokerler her zaman oynanabilir.
    if (card.isWild) return true;
    // Renk eşleşmesi (joker sonrası seçilen rengi de kapsar).
    if (card.color == currentColor) return true;
    // Sayı kartları aynı sayıyla eşleşir.
    if (card.type == CardType.number && top.type == CardType.number) {
      return card.value == top.value;
    }
    // Aynı tür aksiyon kartları (örn. Skip üstüne Skip) eşleşir.
    if (card.type == top.type && card.type != CardType.number) return true;
    return false;
  }
}
