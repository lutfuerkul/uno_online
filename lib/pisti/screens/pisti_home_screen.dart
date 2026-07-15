import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pisti_online_provider.dart';
import '../../services/player_name_store.dart';
import '../theme/pisti_theme.dart';
import 'pisti_bot_screen.dart';

/// Pişti giriş ekranı: ad gir, oyun kur, oda koduyla katıl ya da
/// bilgisayara karşı oyna. `docs/pisti/game.js` `renderHome()` ile birebir
/// aynı görsel dili kullanır.
class PistiHomeScreen extends StatefulWidget {
  const PistiHomeScreen({super.key});

  @override
  State<PistiHomeScreen> createState() => _PistiHomeScreenState();
}

class _PistiHomeScreenState extends State<PistiHomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final name = await PlayerNameStore.loadPistiName();
    if (!mounted || name.isEmpty) return;
    _nameController.text = name;
  }

  void _persistName(String raw) {
    final name = PlayerNameStore.normalize(raw);
    if (_nameController.text != name) {
      _nameController.value = _nameController.value.copyWith(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
    unawaited(PlayerNameStore.savePistiName(name));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validateName() {
    final name = PlayerNameStore.normalize(_nameController.text);
    _nameController.text = name;
    unawaited(PlayerNameStore.savePistiName(name));
    if (name.isEmpty) {
      _toast('Önce bir isim gir.');
      return null;
    }
    if (name.length > PistiOnlineProvider.maxNameLength) {
      _toast('İsim en fazla ${PistiOnlineProvider.maxNameLength} karakter olabilir.');
      return null;
    }
    return name;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
      filled: true,
      fillColor: PistiColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PistiColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PistiColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PistiColors.inputBorder, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PistiOnlineProvider>();

    return Scaffold(
      backgroundColor: PistiColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PİŞTİ',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: PistiColors.primary,
                    letterSpacing: 2,
                    height: 1,
                    shadows: [Shadow(color: PistiColors.logoShadow, offset: Offset(0, 2))],
                  ),
                ),
                const Text(
                  'ONLINE',
                  style: TextStyle(fontSize: 18, letterSpacing: 10, color: Color(0xCCFFFFFF)),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  maxLength: PistiOnlineProvider.maxNameLength,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _persistName,
                  decoration: _inputDecoration('Adınız / Nickname').copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PistiColors.cardBackBg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PistiBotScreen(initialPlayerName: name),
                        ),
                      );
                    },
                    child: const Text('🤖 Bilgisayara Karşı Oyna',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: PistiColors.divider),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PistiColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name != null) provider.createGame(name);
                    },
                    child: const Text('Yeni Oyun Kur', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Oda Kodu (örn. K7P2M)'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name == null) return;
                      if (_codeController.text.trim().isEmpty) {
                        _toast('Oda kodunu gir.');
                        return;
                      }
                      provider.joinGame(_codeController.text, name);
                    },
                    child: const Text('Oyuna Katıl', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Online ya da bilgisayara karşı · 2, 3 ya da 4 kişi · takım yok',
                  style: TextStyle(color: PistiColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: PistiColors.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('← Oyun Seç', style: TextStyle(fontWeight: FontWeight.w700)),
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
