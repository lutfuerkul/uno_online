import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';

class PistiScoreResult {
  final Map<String, int> scores;
  final Map<String, PistiScoreDetail> detail;
  final List<String> winners;

  const PistiScoreResult({
    required this.scores,
    required this.detail,
    required this.winners,
  });
}

/// Pişti destesi, ilk el dağıtımı ve puanlama kurallarını içerir.
class PistiDeckService {
  static const _uuid = Uuid();

  /// [numDecks]=1 → 52 kart (2 oyuncu), 2 → 104 kart (3-4 oyuncu).
  static List<PistiCard> buildDeck({int numDecks = 1}) {
    final deck = <PistiCard>[];
    for (var n = 0; n < numDecks; n++) {
      for (final suit in PistiSuit.values) {
        for (final rank in PistiRank.values) {
          deck.add(PistiCard(suit: suit, rank: rank, id: _uuid.v4()));
        }
      }
    }
    return deck;
  }

  /// Her oyuncuya 4'er kart dağıtır (karılmış destenin sonundan alınır).
  static Map<String, List<PistiCard>> dealHands(
    List<PistiCard> deck,
    List<String> players,
  ) {
    final hands = <String, List<PistiCard>>{};
    for (final p in players) {
      hands[p] = List.generate(4, (_) => deck.removeLast());
    }
    return hands;
  }

  /// Masaya açılış kartlarını koyar; en üstteki (yüzü açık) kart asla vale
  /// olmaz (kapalı kartlar vale olabilir).
  ///
  /// [pile]'da "en üstteki kart = son eleman" kuralına uyması için, destenin
  /// en üstünden çekilen ilk kart (yüzü açık olacak kart) listenin **sonuna**
  /// konur.
  static List<PistiCard> dealTable(List<PistiCard> deck, int tableSize) {
    final table =
        List.generate(tableSize, (_) => deck.removeLast()).reversed.toList();
    var guard = 0;
    while (table.isNotEmpty &&
        table.last.isJack &&
        deck.isNotEmpty &&
        guard++ < 100) {
      final jack = table.removeLast();
      deck.insert(0, jack); // valeyi destenin dibine göm
      table.add(deck.removeLast());
    }
    return table;
  }

  /// Bir eli bitiren dağıtım: normalde 4'er, ama kalan kartlar oyunculara tam
  /// bölünüyorsa ve bu son eli oluşturuyorsa eşit paylaştırılır (örn. 4
  /// kişilik oyunda son el 5'er kart olur).
  static void dealRound(
    Map<String, List<PistiCard>> hands,
    List<String> players,
    List<PistiCard> drawPile,
  ) {
    final n = players.length;
    final remaining = drawPile.length;
    var per = 4;
    if (remaining <= n * 5 && remaining % n == 0) per = remaining ~/ n;
    for (final p in players) {
      if (drawPile.isEmpty) break;
      final take = min(per, drawPile.length);
      hands[p] = List.generate(take, (_) => drawPile.removeLast());
    }
  }

  /// Her normal Pişti +10, vale üstüne vale ile yapılan pişti +15, yakalanan
  /// her As +1, Sinek 2'li +2, Karo 10'lu +3, yakalanan her Vale +1, en çok
  /// kart toplayan +3.
  static PistiScoreResult scoreGame(
    List<String> players,
    Map<String, List<PistiCard>> won,
    Map<String, int> pistiCount,
    Map<String, int> jackPistiCount,
  ) {
    var maxCards = -1;
    final cardCounts = <String, int>{};
    for (final p in players) {
      cardCounts[p] = won[p]?.length ?? 0;
      if (cardCounts[p]! > maxCards) maxCards = cardCounts[p]!;
    }

    final scores = <String, int>{};
    final detail = <String, PistiScoreDetail>{};
    for (final p in players) {
      final cards = won[p] ?? const <PistiCard>[];
      final jackCount = cards.where((c) => c.isJack).length;
      final aceCount = cards.where((c) => c.isAce).length;
      final clubTwoCount = cards.where((c) => c.isClubTwo).length;
      final diamondTenCount = cards.where((c) => c.isDiamondTen).length;
      final mostCards = cardCounts[p] == maxCards && maxCards > 0;
      final pisti = pistiCount[p] ?? 0;
      final jackPisti = jackPistiCount[p] ?? 0;
      final normalPisti = pisti - jackPisti;
      final total = normalPisti * 10 +
          jackPisti * 15 +
          jackCount +
          aceCount +
          clubTwoCount * 2 +
          diamondTenCount * 3 +
          (mostCards ? 3 : 0);
      detail[p] = PistiScoreDetail(
        cardCount: cardCounts[p]!,
        jackCount: jackCount,
        aceCount: aceCount,
        clubTwoCount: clubTwoCount,
        diamondTenCount: diamondTenCount,
        mostCards: mostCards,
        pisti: pisti,
        jackPisti: jackPisti,
        total: total,
      );
      scores[p] = total;
    }

    var best = -1;
    for (final p in players) {
      if (scores[p]! > best) best = scores[p]!;
    }
    final winners = players.where((p) => scores[p] == best).toList();
    return PistiScoreResult(scores: scores, detail: detail, winners: winners);
  }
}
