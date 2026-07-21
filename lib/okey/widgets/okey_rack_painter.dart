import 'package:flutter/material.dart';

import '../theme/okey_theme.dart';

/// Ahşap ıstakayı (taş rafı) çizer — ekteki fotoğraftaki gibi hafif kavisli,
/// önde bir çıkıntısı (lip) olan koyu ahşap bir tepsi. Taşlar bu rafın önündeki
/// çıkıntıya dizilir.
class OkeyRackPainter extends CustomPainter {
  const OkeyRackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Arka panel (dik yüzey) — üstte hafif kavis.
    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * 0.66),
      const Radius.circular(10),
    );
    final backPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [OkeyColors.rackMid, OkeyColors.rackDark],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.66));
    canvas.drawRRect(backRect, backPaint);

    // Ahşap damar dokusu (ince yatay çizgiler).
    final grain = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1;
    for (var y = h * 0.06; y < h * 0.6; y += h * 0.11) {
      canvas.drawLine(Offset(w * 0.03, y), Offset(w * 0.97, y), grain);
    }

    // Ön çıkıntı (taşların oturduğu raf) — daha açık ton, üstte ışık.
    final lipTop = h * 0.58;
    final lipRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, lipTop, w, h - lipTop),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );
    final lipPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [OkeyColors.rackLight, OkeyColors.rackLip],
      ).createShader(Rect.fromLTWH(0, lipTop, w, h - lipTop));
    canvas.drawRRect(lipRect, lipPaint);

    // Çıkıntının üst kenarındaki ince ışık çizgisi.
    final highlight = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(w * 0.02, lipTop + 1), Offset(w * 0.98, lipTop + 1), highlight);
  }

  @override
  bool shouldRepaint(covariant OkeyRackPainter oldDelegate) => false;
}
