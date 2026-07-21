import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/okey_online_provider.dart';
import 'okey_game_screen.dart';
import 'okey_home_screen.dart';

/// Online odaya girildiyse oyun ekranını, aksi halde Okey giriş ekranını
/// gösterir.
class OkeyRootScreen extends StatelessWidget {
  const OkeyRootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OkeyOnlineProvider(),
      child: Builder(
        builder: (context) {
          final inGame =
              context.select<OkeyOnlineProvider, bool>((p) => p.gameId != null);
          return inGame ? const OkeyGameScreen() : const OkeyHomeScreen();
        },
      ),
    );
  }
}
