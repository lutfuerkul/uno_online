import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/player_name_store.dart';
import '../services/player_photo_store.dart';
import '../theme/ui_scale.dart';
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

  /// [s]: bkz. [computeUiScale] — ekrandaki tüm ölçüler bununla çarpılır.
  InputDecoration _inputDecoration(String hint, double s) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0x66FFFFFF), fontSize: 14 * s),
      filled: true,
      fillColor: UnoColors.inputBg,
      contentPadding:
          EdgeInsets.symmetric(vertical: 14 * s, horizontal: 14 * s),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
        borderSide: const BorderSide(color: UnoColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
        borderSide: const BorderSide(color: UnoColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
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
        child: LayoutBuilder(builder: (context, constraints) {
          final s = computeUiScale(constraints);
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24 * s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'uWin',
                    style: TextStyle(
                      fontSize: 72 * s,
                      fontWeight: FontWeight.w900,
                      color: UnoColors.red,
                      letterSpacing: 4,
                      height: 1,
                    ),
                  ),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 18 * s,
                      letterSpacing: 10,
                      color: const Color(0xCCFFFFFF),
                    ),
                  ),
                  SizedBox(height: 24 * s),
                  PlayerPhotoPicker(
                    onChanged: (photo) => _photo = photo,
                    loadSaved: PlayerPhotoStore.loadUnoPhoto,
                    saveNew: PlayerPhotoStore.saveUnoPhoto,
                    borderColor: UnoColors.yellow,
                    backgroundColor: UnoColors.wildCard,
                    badgeColor: UnoColors.yellow,
                    size: 64 * s,
                  ),
                  SizedBox(height: 8 * s),
                  Text(
                    'Profil fotoğrafın (isteğe bağlı) — diğer oyuncular görür',
                    style: TextStyle(color: UnoColors.muted, fontSize: 12 * s),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14 * s),
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    maxLength: GameProvider.maxNameLength,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    onChanged: _persistName,
                    decoration: _inputDecoration('Adınız / Nickname', s)
                        .copyWith(counterText: ''),
                  ),
                  SizedBox(height: 14 * s),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UnoColors.btnUnoBg,
                        foregroundColor: UnoColors.background,
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12 * s)),
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
                      child: Text('🤖 Bilgisayara Karşı Oyna',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Container(height: 1, color: UnoColors.divider),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UnoColors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12 * s)),
                      ),
                      onPressed: () {
                        final name = _validateName();
                        if (name != null) provider.createGame(name, photo: _photo);
                      },
                      child: Text('Yeni Oyun Kur',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    decoration: _inputDecoration('Oda Kodu (örn. K7P2M)', s),
                  ),
                  SizedBox(height: 14 * s),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12 * s)),
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
                      child: Text('Oyuna Katıl',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    'Online: 2-4 kişi · Bilgisayara karşı: 2-4 kişi',
                    style: TextStyle(color: UnoColors.muted, fontSize: 14 * s),
                    textAlign: TextAlign.center,
                  ),
                  if (provider.error != null) ...[
                    SizedBox(height: 12 * s),
                    Text(
                      provider.error!,
                      style: TextStyle(color: UnoColors.error, fontSize: 14 * s),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0x55FFFFFF), width: 2),
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12 * s)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('← Oyun Seç',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
