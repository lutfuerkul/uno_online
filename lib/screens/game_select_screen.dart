import 'package:flutter/material.dart';

import '../okey/screens/okey_root_screen.dart';
import '../pisti/screens/pisti_root_screen.dart';
import '../theme/ui_scale.dart';
import 'uno_root_screen.dart';

/// Açılış ekranı: UNO ya da Pişti seçilir. `docs/index.html`'deki seçim
/// ekranıyla birebir aynı görsel dili kullanır (koyu lacivert zemin, oyun
/// kartları listesi). Tüm ölçüler [computeUiScale] katsayısıyla çarpılır —
/// tahtalardaki tek-katsayı yaklaşımının aynısı.
class GameSelectScreen extends StatelessWidget {
  const GameSelectScreen({super.key});

  static const _background = Color(0xFF12203A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final s = computeUiScale(constraints);
            return Center(
              child: SingleChildScrollView(
                padding: uiContentPadding(constraints, s,
                    horizontal: 20 * s, vertical: 32 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/icons/app_icon.png',
                      width: 64 * s,
                      height: 64 * s,
                    ),
                    SizedBox(height: 10 * s),
                    Text(
                      'uWin•Okey•Pişti',
                      style: TextStyle(
                        fontSize: 30 * s,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    Text(
                      'Oynamak istediğin oyunu seç',
                      style: TextStyle(
                          color: const Color(0xAAFFFFFF), fontSize: 15 * s),
                    ),
                    SizedBox(height: 28 * s),
                    _GameCard(
                      iconAsset: 'assets/icons/uwin_icon.png',
                      title: 'uWin',
                      subtitle: '2-4 kişilik, oda koduyla online',
                      borderColor: const Color(0x66C62828),
                      scale: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const UnoRootScreen()),
                      ),
                    ),
                    SizedBox(height: 16 * s),
                    _GameCard(
                      iconAsset: 'assets/icons/okey_icon.png',
                      title: 'Okey',
                      subtitle: '2-4 kişilik, oda koduyla online',
                      borderColor: const Color(0x6600796B),
                      scale: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const OkeyRootScreen()),
                      ),
                    ),
                    SizedBox(height: 16 * s),
                    _GameCard(
                      iconAsset: 'assets/icons/pisti_icon.png',
                      title: 'Pişti',
                      subtitle: '2-4 kişilik, oda koduyla online',
                      borderColor: const Color(0x661565C0),
                      scale: s,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const PistiRootScreen()),
                      ),
                    ),
                    SizedBox(height: 28 * s),
                    Text(
                      'Her oyun gerçek zamanlı, oda koduyla oynanır.',
                      style: TextStyle(
                          color: const Color(0x66FFFFFF), fontSize: 12 * s),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
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

  /// bkz. [computeUiScale] — karttaki tüm ölçüler bununla çarpılır.
  final double scale;

  const _GameCard({
    this.iconAsset,
    this.emoji,
    required this.title,
    required this.subtitle,
    required this.borderColor,
    required this.onTap,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return SizedBox(
      width: 340 * s,
      child: Material(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(18 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(18 * s),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18 * s, vertical: 16 * s),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18 * s),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14 * s),
                  child: iconAsset != null
                      ? Image.asset(iconAsset!, width: 52 * s, height: 52 * s)
                      : Container(
                          width: 52 * s,
                          height: 52 * s,
                          alignment: Alignment.center,
                          color: const Color(0x2200796B),
                          child: Text(emoji ?? '🎲',
                              style: TextStyle(fontSize: 30 * s)),
                        ),
                ),
                SizedBox(width: 16 * s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20 * s,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2 * s),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 13 * s, color: const Color(0xAAFFFFFF)),
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
