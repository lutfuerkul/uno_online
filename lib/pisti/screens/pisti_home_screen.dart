import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pisti_local_provider.dart';
import 'pisti_game_screen.dart';

/// Pişti giriş akışı: şu an yalnızca "Bilgisayara Karşı Oyna" (çevrimdışı)
/// modu var; oyuncu sayısı seçilir, sonra oyun tahtası gösterilir.
class PistiHomeScreen extends StatelessWidget {
  const PistiHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PistiLocalProvider(),
      child: const _PistiRoot(),
    );
  }
}

class _PistiRoot extends StatelessWidget {
  const _PistiRoot();

  @override
  Widget build(BuildContext context) {
    final started =
        context.select<PistiLocalProvider, bool>((p) => p.state != null);
    return started ? const PistiGameScreen() : const _PistiSetupForm();
  }
}

class _PistiSetupForm extends StatefulWidget {
  const _PistiSetupForm();

  @override
  State<_PistiSetupForm> createState() => _PistiSetupFormState();
}

class _PistiSetupFormState extends State<_PistiSetupForm> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _start(int total) {
    context.read<PistiLocalProvider>().startGame(
          playerName: _nameController.text.trim(),
          totalPlayers: total,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pişti')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🃏', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                const Text(
                  'İnternet gerekmez, botlara karşı oyna.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'İsmin (opsiyonel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                for (final n in [2, 3, 4]) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _start(n),
                      child: Text('$n Oyuncu (sen + ${n - 1} bot)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
