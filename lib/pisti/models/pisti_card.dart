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

  String get suitNameTr {
    switch (suit) {
      case PistiSuit.spades:
        return 'Maça';
      case PistiSuit.hearts:
        return 'Kupa';
      case PistiSuit.diamonds:
        return 'Karo';
      case PistiSuit.clubs:
        return 'Sinek';
    }
  }

  String get rankNameTr {
    switch (rank) {
      case PistiRank.ace:
        return 'As';
      case PistiRank.jack:
        return 'Vale';
      case PistiRank.queen:
        return 'Kız';
      case PistiRank.king:
        return 'Papaz';
      default:
        return rankLabel;
    }
  }

  /// "Karo 7", "Maça Vale", "Kupa As" gibi Türkçe kart adı.
  String get nameTr => '$suitNameTr $rankNameTr';

  Map<String, dynamic> toMap() => {'suit': suit.name, 'rank': rank.name, 'id': id};

  factory PistiCard.fromMap(Map<String, dynamic> map) => PistiCard(
        suit: PistiSuit.values.byName(map['suit'] as String),
        rank: PistiRank.values.byName(map['rank'] as String),
        id: map['id'] as String,
      );
}
