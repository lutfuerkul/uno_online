/// Pişti'de kullanılan klasik iskambil kağıdı modeli.
enum PistiSuit { clubs, diamonds, hearts, spades }

enum PistiRank {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
}

class PistiCard {
  final PistiSuit suit;
  final PistiRank rank;

  /// Kartı benzersiz kılan kimlik (2 desteli oyunda aynı kart iki kez
  /// bulunabildiği için gerekli).
  final String id;

  const PistiCard({required this.suit, required this.rank, required this.id});

  bool get isJack => rank == PistiRank.jack;
  bool get isAce => rank == PistiRank.ace;
  bool get isClubTwo => suit == PistiSuit.clubs && rank == PistiRank.two;
  bool get isDiamondTen => suit == PistiSuit.diamonds && rank == PistiRank.ten;
  bool get isRed => suit == PistiSuit.diamonds || suit == PistiSuit.hearts;

  String get suitSymbol {
    switch (suit) {
      case PistiSuit.clubs:
        return '♣';
      case PistiSuit.diamonds:
        return '♦';
      case PistiSuit.hearts:
        return '♥';
      case PistiSuit.spades:
        return '♠';
    }
  }

  String get rankLabel {
    switch (rank) {
      case PistiRank.ace:
        return 'A';
      case PistiRank.jack:
        return 'J';
      case PistiRank.queen:
        return 'Q';
      case PistiRank.king:
        return 'K';
      default:
        return '${rank.index + 1}';
    }
  }
}
