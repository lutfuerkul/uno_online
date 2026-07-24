import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/player_name_store.dart';
import '../services/player_photo_store.dart';
import '../theme/uno_theme.dart';
import '../widgets/player_photo_picker.dart';
import 'uno_bot_screen.dart';

/// Giriş ekranı: ad gir, oyun kur veya oda koduyla katıl. `docs/uno/game.js`
/// `renderHome()` ile birebir aynı görsel dili kullanır.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final name = await PlayerNameStore.loadUnoName();
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
    unawaited(PlayerNameStore.saveUnoName(name));
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
    unawaited(PlayerNameStore.saveUnoName(name));
    if (name.isEmpty) {
      _toast('Önce bir isim gir.');
      return null;
    }
    if (name.length > GameProvider.maxNameLength) {
      _toast('İsim en fazla ${GameProvider.maxNameLength} karakter olabilir.');
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
      fillColor: UnoColors.inputBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: UnoColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: UnoColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: UnoColors.inputBorder, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: UnoColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UNO',
                  style: TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: UnoColors.red,
                    letterSpacing: 4,
                    height: 1,
                  ),
                ),
                const Text(
                  'ONLINE',
                  style: TextStyle(
                    fontSize: 18,
                    letterSpacing: 10,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
                const SizedBox(height: 24),
                PlayerPhotoPicker(
                  onChanged: (photo) => _photo = photo,
                  loadSaved: PlayerPhotoStore.loadUnoPhoto,
                  saveNew: PlayerPhotoStore.saveUnoPhoto,
                  borderColor: UnoColors.yellow,
                  backgroundColor: UnoColors.wildCard,
                  badgeColor: UnoColors.yellow,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Profil fotoğrafın (isteğe bağlı) — diğer oyuncular görür',
                  style: TextStyle(color: UnoColors.muted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  textAlign: TextAlign.center,
                  maxLength: GameProvider.maxNameLength,
                  style: const TextStyle(color: Colors.white),
                  onChanged: _persistName,
                  decoration: _inputDecoration('Adınız / Nickname').copyWith(counterText: ''),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UnoColors.btnUnoBg,
                      foregroundColor: UnoColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UnoBotScreen(initialPlayerName: name),
                        ),
                      );
                    },
                    child: const Text('🤖 Bilgisayara Karşı Oyna',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: UnoColors.divider),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UnoColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name != null) provider.createGame(name, photo: _photo);
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final name = _validateName();
                      if (name == null) return;
                      if (_codeController.text.trim().isEmpty) {
                        _toast('Oda kodunu gir.');
                        return;
                      }
                      provider.joinGame(_codeController.text, name, photo: _photo);
                    },
                    child: const Text('Oyuna Katıl', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Online: 2-4 kişi · Bilgisayara karşı: 2-4 kişi',
                  style: TextStyle(color: UnoColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                if (provider.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    provider.error!,
                    style: const TextStyle(color: UnoColors.error, fontSize: 14),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
