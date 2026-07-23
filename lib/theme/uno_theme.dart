import 'package:flutter/material.dart';

import '../models/uno_card.dart';

/// `docs/uno/index.html`'deki CSS ile birebir eşleşen renk paleti.
class UnoColors {
  UnoColors._();

  static const background = Color(0xFF1B2430);
  static const topbar = Color(0xFF131A24);
  static const hand = Color(0xFF131A24);

  static const red = Color(0xFFD32F2F);
  static const yellow = Color(0xFFF9A825);
  static const green = Color(0xFF388E3C);
  static const blue = Color(0xFF1976D2);
  static const wildCard = Color(0xFF161616);
  static const cardBack = Color(0xFFC62828);

  static const inputBg = Color(0x11FFFFFF);
  static const inputBorder = Color(0x33FFFFFF);
  static const divider = Color(0x22FFFFFF);
  static const error = Color(0xFFFF8A80);
  static const muted = Color(0x99FFFFFF);

  static const oppTurnBorder = Color(0xFF66BB6A);
  static const oppTurnBg = Color(0x2266BB6A);

  static const btnPass = Color(0xFF455A64);
  static const btnUnoBg = Color(0xFFF9A825);
  static const unoTag = Color(0xFF66BB6A);
  static const blockedTag = Color(0xFFFF8A80);
  static const lastAction = Color(0xFFFFE082);

  static const turnMine = Color(0xFF2E7D32);
  static const turnTheirs = Color(0xFF33414F);
  static const turnTheirsText = Color(0xBBFFFFFF);

  static const codeBoxBg = Color(0x22D32F2F);
  static const lobbyRowBg = Color(0x11FFFFFF);

  static const pickerBg = Color(0xFF222C38);
  static const targetBtnBg = Color(0xFF37474F);

  static Color forCard(CardColor color) {
    switch (color) {
      case CardColor.red:
        return red;
      case CardColor.yellow:
        return yellow;
      case CardColor.green:
        return green;
      case CardColor.blue:
        return blue;
      case CardColor.wild:
        return wildCard;
    }
  }
}
