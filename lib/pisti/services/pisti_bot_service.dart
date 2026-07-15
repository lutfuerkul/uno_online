import '../models/pisti_card.dart';
import '../models/pisti_game_state.dart';

/// Bot kart seçimi: önce (mümkünse pişti yapan) sayı eşleşmesiyle yakalar;
/// masada birden fazla kart varken vale ile süpürür; aksi halde rakibe puan
/// vermemek için en değersiz kartı atar (vale mümkün olduğunca saklanır).
class PistiBotService {
  static PistiCard choose(PistiGameState state, String botId) {
    final hand = state.hands[botId] ?? const <PistiCard>[];
    final pile = state.pile;
    final top = pile.isNotEmpty ? pile.last : null;

    final matches = hand
        .where((c) => !c.isJack && top != null && top.rank == c.rank)
        .toList();
    if (matches.isNotEmpty) return matches.first;

    final jacks = hand.where((c) => c.isJack).toList();
    if (jacks.isNotEmpty && pile.length >= 2) return jacks.first;

    final nonJacks = hand.where((c) => !c.isJack).toList();
    if (nonJacks.isEmpty) return jacks.first;

    int valueOf(PistiCard c) {
      if (c.isAce) return 3;
      if (c.isClubTwo) return 4;
      if (c.isDiamondTen) return 5;
      return 1;
    }

    final sorted = [...nonJacks]
      ..sort((a, b) => valueOf(a).compareTo(valueOf(b)));
    return sorted.first;
  }
}
