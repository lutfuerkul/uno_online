import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/uno_card.dart';
import '../theme/uno_theme.dart';

/// Bir uWin kart yüzünü (veya arka yüzünü) kod ile çizer — bir görsel
/// dosyasına bağımlı değildir. Kart oyunlarının ortak/işlevsel dilini
/// (renkli zemin, köşe endeksleri, ortada büyük sembol) kullanır ama
/// telif nedeniyle bilinen UNO kartlarının kendine özgü ögelerinden
/// kasıtlı olarak farklıdır:
///  - Ortada eğik oval yerine döndürülmüş kare (baklava dilimi) paneli,
///  - Kalın beyaz çerçeve yerine kartın kendi renginin koyu tonunda
///    ince bir kenarlık,
///  - Joker'de dairesel renk çarkı yerine 2x2 renkli kare rozet,
///  - Skip/Reverse için UNO'nun kavisli ok ikonları yerine sade Unicode
///    piktogramlar (⊘ / ⇄),
///  - Arka yüzde UNO'nun kırmızı-oval logosu yerine "uWin" yazı markası.
class CardWidget extends StatelessWidget {
  final UnoCard? card;

  /// true ise kartın arka yüzü gösterilir (rakibin elindeki kartlar için).
  final bool faceDown;

  /// Oynanabilir kartları vurgulamak için dış parıltı.
  final bool highlighted;

  final VoidCallback? onTap;
  final double width;

  /// Joker kartlar oynandıktan sonra (masadaki açık kart) hangi renk
  /// seçildiyse o renkte çerçeve gösterilir. Elde duran (henüz oynanmamış)
  /// jokerlerde null bırakılır.
  final CardColor? chosenColorOverride;

  const CardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.highlighted = false,
    this.onTap,
    this.width = 62,
    this.chosenColorOverride,
  });

  bool get _isFaceDown => faceDown || card == null;

  Color get _bgColor {
    if (_isFaceDown) return UnoColors.background;
    final c = card!;
    if (c.isWild) return UnoColors.wildCard;
    return UnoColors.forCard(c.color);
  }

  Color get _borderColor {
    if (_isFaceDown) return const Color(0xFF3A4656);
    return Color.lerp(_bgColor, Colors.black, 0.35)!;
  }

  List<BoxShadow> _cardShadows(double width) {
    if (highlighted) {
      return [
        BoxShadow(
          color: const Color(0xDDFFFFFF),
          spreadRadius: width * 0.06,
          blurRadius: 0,
        ),
        const BoxShadow(color: Color(0x70000000), blurRadius: 6, offset: Offset(0, 2)),
      ];
    }
    return const [
      BoxShadow(color: Color(0x60000000), blurRadius: 5, offset: Offset(0, 2)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final height = width * 1.5;
    // Eski (görsel tabanlı) kartlarla aynı ebat: dış çerçeve 120 birim
    // genişlikte 14 birim yuvarlatılmıştı, aynı oran korunuyor.
    final radius = BorderRadius.circular(width * 14 / 120);

    final overrideColor = (!_isFaceDown && card!.isWild && chosenColorOverride != null)
        ? UnoColors.forCard(chosenColorOverride!)
        : null;

    final body = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: radius,
        border: Border.all(color: _borderColor, width: math.max(1.5, width * 0.03)),
        boxShadow: _cardShadows(width),
      ),
      foregroundDecoration: overrideColor == null
          ? null
          : BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: overrideColor, width: width * 0.08),
            ),
      clipBehavior: Clip.antiAlias,
      child: _isFaceDown ? _buildBack(width, height) : _buildFace(width, height),
    );

    return GestureDetector(
      onTap: onTap,
      child: body,
    );
  }

  Widget _buildBack(double w, double h) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: -math.pi / 9,
          child: Container(
            width: w * 1.4,
            height: h * 0.18,
            color: UnoColors.red.withOpacity(0.85),
          ),
        ),
        Text(
          'uWin',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            fontSize: w * 0.30,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildFace(double w, double h) {
    final c = card!;
    final cornerLabel = c.type == CardType.number ? '${c.value}' : c.label;
    return Stack(
      children: [
        Positioned(
          top: h * 0.06,
          left: w * 0.12,
          child: _cornerIndex(cornerLabel, c.type == CardType.number, w),
        ),
        Positioned(
          bottom: h * 0.06,
          right: w * 0.12,
          child: Transform.rotate(
            angle: math.pi,
            child: _cornerIndex(cornerLabel, c.type == CardType.number, w),
          ),
        ),
        Center(child: c.isWild ? _wildBadge(c, w) : _colorSymbol(c, w)),
      ],
    );
  }

  Widget _cornerIndex(String label, bool isNumber, double w) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: w * (isNumber ? 0.24 : 0.15),
        height: 1,
      ),
    );
  }

  /// Sayı/skip/reverse/+2 kartları: eğik oval yerine döndürülmüş kare
  /// (baklava dilimi) panel, üzerinde sembol.
  Widget _colorSymbol(UnoCard c, double w) {
    final panel = w * 0.60;
    final fg = UnoColors.forCard(c.color);
    final label = c.type == CardType.number ? '${c.value}' : c.label;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: panel,
            height: panel,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(panel * 0.16),
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w900,
            fontSize: w * (c.type == CardType.number ? 0.50 : 0.28),
            height: 1,
          ),
        ),
      ],
    );
  }

  /// Joker / +4: dairesel renk çarkı yerine 2x2 renkli kare rozet.
  Widget _wildBadge(UnoCard c, double w) {
    final side = w * 0.58;
    final gap = side * 0.06;
    final outer = BorderRadius.circular(side * 0.16);

    Widget cell(Color color) => Container(color: color);

    final grid = ClipRRect(
      borderRadius: outer,
      child: SizedBox(
        width: side,
        height: side,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(UnoColors.red)),
                  SizedBox(width: gap),
                  Expanded(child: cell(UnoColors.blue)),
                ],
              ),
            ),
            SizedBox(height: gap),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: cell(UnoColors.yellow)),
                  SizedBox(width: gap),
                  Expanded(child: cell(UnoColors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (c.type == CardType.wild) return grid;

    return Stack(
      alignment: Alignment.center,
      children: [
        grid,
        Container(
          padding: EdgeInsets.symmetric(horizontal: w * 0.07, vertical: w * 0.025),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(w * 0.08),
            border: Border.all(color: Colors.white, width: w * 0.012),
          ),
          child: Text(
            '+4',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: w * 0.22,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
