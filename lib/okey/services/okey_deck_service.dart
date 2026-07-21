import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/okey_tile.dart';

/// Okey destesini kurar ve ilk el dağıtımını yapar.
class OkeyDeckService {
  static const _uuid = Uuid();

  /// İlk hamleyi yapan oyuncu 15, diğerleri 14 taş alır.
  static const int starterTileCount = 15;
  static const int normalTileCount = 14;

  /// 106 taş: 4 renk × 1–13 × 2 kopya (104) + 2 sahte okey.
  static List<OkeyTile> buildDeck() {
    final deck = <OkeyTile>[];
    for (var copy = 0; copy < 2; copy++) {
      for (final color in OkeyColor.values) {
        for (var number = 1; number <= 13; number++) {
          deck.add(OkeyTile(
            color: color,
            number: number,
            isFakeJoker: false,
            id: _uuid.v4(),
          ));
        }
      }
    }
    for (var i = 0; i < 2; i++) {
      deck.add(OkeyTile(
        color: OkeyColor.yellow,
        number: 0,
        isFakeJoker: true,
        id: _uuid.v4(),
      ));
    }
    return deck;
  }

  /// Deste kurar, karar, göstergeyi belirler ve elleri dağıtır.
  /// [starterIndex] sırayı ilk açan oyuncunun (15 taş alan) sırasıdır.
  static OkeyDeal deal({required List<String> players, required int starterIndex}) {
    final deck = buildDeck()..shuffle(Random());

    // Gösterge: sahte okey olmamalı (okey belirsiz kalmasın diye yeniden çek).
    OkeyTile indicator;
    do {
      indicator = deck.removeLast();
    } while (indicator.isFakeJoker && deck.isNotEmpty);

    final hands = <String, List<OkeyTile>>{};
    for (var i = 0; i < players.length; i++) {
      final count = i == starterIndex ? starterTileCount : normalTileCount;
      hands[players[i]] = List.generate(count, (_) => deck.removeLast());
    }

    return OkeyDeal(hands: hands, drawPile: deck, indicator: indicator);
  }
}

class OkeyDeal {
  final Map<String, List<OkeyTile>> hands;
  final List<OkeyTile> drawPile;
  final OkeyTile indicator;

  const OkeyDeal({
    required this.hands,
    required this.drawPile,
    required this.indicator,
  });
}
