import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// Online odaya girildiyse oyun ekranını, aksi halde UNO giriş ekranını
/// gösterir.
class UnoRootScreen extends StatelessWidget {
  const UnoRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inGame = context.select<GameProvider, bool>((p) => p.gameId != null);
    return inGame ? const GameScreen() : const HomeScreen();
  }
}
