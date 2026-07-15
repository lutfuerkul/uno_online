import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/local_uno_provider.dart';
import 'local_uno_game_screen.dart';

/// "Bilgisayara Karşı Oyna" akışını yönetir: önce oyuncu sayısı seçilir,
/// sonra yerel (çevrimdışı) oyun tahtası gösterilir.
class UnoBotScreen extends StatelessWidget {
  const UnoBotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocalUnoProvider(),
      child: const _UnoBotRoot(),
    );
  }
}

class _UnoBotRoot extends StatelessWidget {
  const _UnoBotRoot();

  @override
  Widget build(BuildContext context) {
    final started =
        context.select<LocalUnoProvider, bool>((p) => p.state != null);
    return started ? const LocalUnoGameScreen() : const _UnoBotSetupForm();
  }
}

class _UnoBotSetupForm extends StatefulWidget {
  const _UnoBotSetupForm();

  @override
  State<_UnoBotSetupForm> createState() => _UnoBotSetupFormState();
}

class _UnoBotSetupFormState extends State<_UnoBotSetupForm> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _start(int total) {
    context.read<LocalUnoProvider>().startGame(
          playerName: _nameController.text.trim(),
          totalPlayers: total,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bilgisayara Karşı')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🤖', style: TextStyle(fontSize: 64)),
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
