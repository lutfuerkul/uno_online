/// UNO kartını temsil eden model.
///
/// Kartlar Firestore'da `Map` olarak saklanır; [toMap] / [fromMap] ile
/// çevrilir.
enum CardColor { red, yellow, green, blue, wild }

enum CardType { number, skip, reverse, drawTwo, wild, wildDrawFour }

class UnoCard {
  /// Kartın rengi. Joker kartlarda [CardColor.wild].
  final CardColor color;

  /// Kartın türü (sayı, skip, +2, joker...).
  final CardType type;

  /// Yalnızca sayı kartlarında dolu (0-9), diğerlerinde null.
  final int? value;

  /// Kartı benzersiz kılan kimlik (aynı kart iki kez olabildiği için gerekli).
  final String id;

  const UnoCard({
    required this.color,
    required this.type,
    required this.id,
    this.value,
  });

  /// Renk seçtiren joker kartlar (Joker ve +4).
  bool get isWild => type == CardType.wild || type == CardType.wildDrawFour;

  Map<String, dynamic> toMap() => {
        'color': color.name,
        'type': type.name,
        'value': value,
        'id': id,
      };

  factory UnoCard.fromMap(Map<String, dynamic> map) => UnoCard(
        color: CardColor.values.byName(map['color'] as String),
        type: CardType.values.byName(map['type'] as String),
        value: map['value'] as int?,
        id: map['id'] as String,
      );

  /// Ekranda gösterilecek kısa etiket.
  String get label {
    switch (type) {
      case CardType.number:
        return '$value';
      case CardType.skip:
        return '⊘';
      case CardType.reverse:
        return '⇄';
      case CardType.drawTwo:
        return '+2';
      case CardType.wild:
        return 'JOKER';
      case CardType.wildDrawFour:
        return '+4';
    }
  }
}
