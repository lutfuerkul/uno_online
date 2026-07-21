/// Okey taşı: dört renk (sarı, kırmızı, siyah, mavi) × 1–13 sayı, her taştan
/// iki kopya (104 taş) + iki sahte okey (joker) = toplam 106 taş.
///
/// Bir taşın "okey" (joker) olup olmadığı taşın kendisiyle değil, o eldeki
/// göstergeyle belirlenir; bu yüzden joker kontrolü [OkeyGameState] üzerinden
/// yapılır. Sahte okey (`isFakeJoker`) her zaman jokerdir.
enum OkeyColor { yellow, red, black, blue }

class OkeyTile {
  /// Sahte okeyde renk anlamsızdır (yer tutucu olarak [OkeyColor.yellow] verilir).
  final OkeyColor color;

  /// 1–13. Sahte okeyde 0.
  final int number;

  final bool isFakeJoker;

  /// Aynı taştan iki kopya bulunabildiği için her taşı benzersiz kılan kimlik.
  final String id;

  const OkeyTile({
    required this.color,
    required this.number,
    required this.isFakeJoker,
    required this.id,
  });

  /// Taşın renk+sayı kodu (0..51); sıralama ve çözümleme için kullanılır.
  /// Sahte okeyde -1.
  int get code => isFakeJoker ? -1 : color.index * 13 + (number - 1);

  String get colorNameTr {
    switch (color) {
      case OkeyColor.yellow:
        return 'Sarı';
      case OkeyColor.red:
        return 'Kırmızı';
      case OkeyColor.black:
        return 'Siyah';
      case OkeyColor.blue:
        return 'Mavi';
    }
  }

  /// "Kırmızı 7", "Sahte Okey" gibi Türkçe taş adı.
  String get nameTr => isFakeJoker ? 'Sahte Okey' : '$colorNameTr $number';

  Map<String, dynamic> toMap() =>
      {'c': color.name, 'n': number, 'j': isFakeJoker, 'id': id};

  factory OkeyTile.fromMap(Map<String, dynamic> map) => OkeyTile(
        color: OkeyColor.values.byName(map['c'] as String),
        number: (map['n'] as num?)?.toInt() ?? 0,
        isFakeJoker: map['j'] as bool? ?? false,
        id: map['id'] as String,
      );
}
