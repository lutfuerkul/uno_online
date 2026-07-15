import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pisti_online_provider.dart';
import 'pisti_game_screen.dart';
import 'pisti_home_screen.dart';

/// Online odaya girildiyse oyun ekranını, aksi halde Pişti giriş ekranını
/// gösterir.
class PistiRootScreen extends StatelessWidget {
  const PistiRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PistiOnlineProvider(),
      child: Builder(
        builder: (context) {
          final inGame = context.select<PistiOnlineProvider, bool>((p) => p.gameId != null);
          return inGame ? const PistiGameScreen() : const PistiHomeScreen();
        },
      ),
    );
  }
}
