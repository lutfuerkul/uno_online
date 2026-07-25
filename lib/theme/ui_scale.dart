import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Ekranın gerçek boyutunu sabit bir referansa (390x844 — yaygın bir telefon
/// ölçüsü) oranlayan TEK katsayı; aşırı büyüme/küçülmeyi önlemek için
/// 0.75-1.15 arasına sıkıştırılır. Oyun tahtalarındaki
/// (`_computeScale`) yaklaşımın aynısı — oyun seçim ve kurulum ekranlarında
/// da yazı puntoları, buton/fotoğraf boyutları ve boşluklar bu katsayıyla
/// çarpılır ki tüm ekran, tahtalarla aynı biçimde orantılı büyüyüp küçülsün.
double computeUiScale(BoxConstraints c) {
  const refW = 390.0;
  const refH = 844.0;
  final w = c.maxWidth.isFinite ? c.maxWidth : refW;
  final h = c.maxHeight.isFinite ? c.maxHeight : refH;
  return math.min(w / refW, h / refH).clamp(0.75, 1.15);
}
