import 'package:flutter/material.dart';

import '../pisti/screens/pisti_home_screen.dart';
import 'uno_root_screen.dart';

/// Açılış ekranı: UNO ya da Pişti seçilir (web sürümündeki seçim ekranının
/// Flutter karşılığı).
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kart Oyunları',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text('Oynamak istediğin oyunu seç'),
                const SizedBox(height: 32),
                _GameCard(
                  title: 'UNO',
                  subtitle: '2-4 kişilik, online ya da bilgisayara karşı',
                  color: const Color(0xFFD32F2F),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UnoRootScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _GameCard(
                  title: 'Pişti',
                  subtitle: '2-4 kişilik, bilgisayara karşı (çevrimdışı)',
                  color: const Color(0xFF1565C0),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PistiHomeScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        color: color.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withOpacity(0.4), width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
