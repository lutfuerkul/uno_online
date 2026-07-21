import 'package:flutter/material.dart';

import '../models/okey_tile.dart';

/// Okey için renk paleti. Yeşil çuha masa, ahşap ıstaka ve fildişi taşlar.
class OkeyColors {
  OkeyColors._();

  static const background = Color(0xFF0E3A2A);
  static const topbar = Color(0xFF08281C);
  static const middle = Color(0xFF124a34);
  static const felt = Color(0xFF0F4230);

  static const primary = Color(0xFF00796B);
  static const accent = Color(0xFFFFB300);
  static const logoShadow = Color(0xFF004D40);

  static const inputBg = Color(0x11FFFFFF);
  static const inputBorder = Color(0x33FFFFFF);
  static const divider = Color(0x22FFFFFF);
  static const error = Color(0xFFFF8A80);
  static const muted = Color(0x99FFFFFF);
  static const label = Color(0xAAFFFFFF);

  // Taş yüzü
  static const tileFace = Color(0xFFF3ECD8);
  static const tileFaceHi = Color(0xFFFBF6E9);
  static const tileNub = Color(0x22000000);
  static const tileBackBg = Color(0xFF0D5C4A);
  static const tileBackBorder = Color(0xFFFFF3D6);

  // Istaka (ahşap raf)
  static const rackDark = Color(0xFF4E2E1A);
  static const rackMid = Color(0xFF6B3F24);
  static const rackLight = Color(0xFF7E4B2C);
  static const rackLip = Color(0xFF3B2114);

  static const turnMine = Color(0xFF2E7D32);
  static const turnTheirs = Color(0xFF10402D);
  static const turnTheirsText = Color(0xBBFFFFFF);

  static const oppTurnBorder = Color(0xFFFFCA28);
  static const oppTurnBg = Color(0x22FFCA28);

  static const okeyGlow = Color(0xFFFFD54F);
  static const lastAction = Color(0xFFFFE082);

  static const codeBoxBg = Color(0x2200796B);
  static const lobbyRowBg = Color(0x11FFFFFF);
  static const scoreRowBg = Color(0x11FFFFFF);
  static const scoreWinBg = Color(0x22FFCA28);

  /// Taş sayısının rengi (fildişi zeminde okunur tonlar).
  static Color tileNumberColor(OkeyColor color) {
    switch (color) {
      case OkeyColor.yellow:
        return const Color(0xFFE0A100);
      case OkeyColor.red:
        return const Color(0xFFC62828);
      case OkeyColor.black:
        return const Color(0xFF1C1C1C);
      case OkeyColor.blue:
        return const Color(0xFF1565C0);
    }
  }
}
