import 'package:flutter/material.dart';

import '../okey/screens/okey_root_screen.dart';
import '../pisti/screens/pisti_root_screen.dart';
import 'uno_root_screen.dart';

/// Açılış ekranı: UNO ya da Pişti seçilir. `docs/index.html`'deki seçim
/// ekranıyla birebir aynı görsel dili kullanır (koyu lacivert zemin, oyun
/// kartları listesi).
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  static const _background = Color(0xFF12203A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icons/app_icon.png',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Uno•Okey•Pişti',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Oynamak istediğin oyunu seç',
                  style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 15),
                ),
                const SizedBox(height: 28),
                _GameCard(
                  iconAsset: 'assets/icons/uno_icon.png',
                  title: 'UNO',
                  subtitle: '2-4 kişilik, oda koduyla online',
                  borderColor: const Color(0x66C62828),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UnoRootScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _GameCard(
                  iconAsset: 'assets/icons/okey_icon.png',
                  title: 'Okey',
                  subtitle: '2-4 kişilik, oda koduyla online',
                  borderColor: const Color(0x6600796B),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OkeyRootScreen()),
                  ),
                ),
                const SizedBox(height: 16),
                _GameCard(
                  iconAsset: 'assets/icons/pisti_icon.png',
                  title: 'Pişti',
                  subtitle: '2-4 kişilik, oda koduyla online',
                  borderColor: const Color(0x661565C0),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PistiRootScreen()),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Her oyun gerçek zamanlı, oda koduyla oynanır.',
                  style: TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                  textAlign: TextAlign.center,
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
  final String? iconAsset;
  final String? emoji;
  final String title;
  final String subtitle;
  final Color borderColor;
  final VoidCallback onTap;

  const _GameCard({
    this.iconAsset,
    this.emoji,
    required this.title,
    required this.subtitle,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Material(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: iconAsset != null
                      ? Image.asset(iconAsset!, width: 52, height: 52)
                      : Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          color: const Color(0x2200796B),
                          child: Text(emoji ?? '🎲',
                              style: const TextStyle(fontSize: 30)),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: Color(0xAAFFFFFF)),
                      ),
                    ],
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
