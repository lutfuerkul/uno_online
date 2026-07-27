import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/player_name_store.dart';
import '../../theme/ui_scale.dart';
import '../providers/okey_online_provider.dart';
import '../theme/okey_theme.dart';
import '../widgets/okey_photo_picker.dart';
import 'okey_bot_screen.dart';

/// Okey giriş ekranı: ad gir, oyun kur, oda koduyla katıl ya da bilgisayara
/// karşı oyna.
class OkeyHomeScreen extends StatefulWidget {
  const OkeyHomeScreen({super.key});

  @override
  State<OkeyHomeScreen> createState() => _OkeyHomeScreenState();
}

class _OkeyHomeScreenState extends State<OkeyHomeScreen> {
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  String? _photo;

  @override
  void initState() {
    super.initState();
    _loadSavedName();
  }

  Future<void> _loadSavedName() async {
    final name = await PlayerNameStore.loadOkeyName();
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
    unawaited(PlayerNameStore.saveOkeyName(name));
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
    unawaited(PlayerNameStore.saveOkeyName(name));
    if (name.isEmpty) {
      _toast('Önce bir isim gir.');
      return null;
    }
    if (name.length > OkeyOnlineProvider.maxNameLength) {
      _toast(
          'İsim en fazla ${OkeyOnlineProvider.maxNameLength} karakter olabilir.');
      return null;
    }
    return name;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// [s]: bkz. [computeUiScale] — ekrandaki tüm ölçüler bununla çarpılır.
  InputDecoration _inputDecoration(String hint, double s) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: const Color(0x66FFFFFF), fontSize: 14 * s),
      filled: true,
      fillColor: OkeyColors.inputBg,
      contentPadding:
          EdgeInsets.symmetric(vertical: 14 * s, horizontal: 14 * s),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
        borderSide: const BorderSide(color: OkeyColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
        borderSide: const BorderSide(color: OkeyColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12 * s),
        borderSide: const BorderSide(color: OkeyColors.inputBorder, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OkeyOnlineProvider>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      // Bu kurulum ekranının zemin tonu UNO'nunkiyle aynı (#1B2430) —
      // yalnızca bu ekran için; oyun içi renkler (OkeyColors) değişmedi.
      backgroundColor: const Color(0xFF1B2430),
      body: SafeArea(
        child: Builder(builder: (context) {
          final constraints = menuLayoutConstraints(context);
          final s = computeMenuUiScale(context);
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
          return Center(
            child: SingleChildScrollView(
              padding: uiContentPadding(constraints, s,
                      horizontal: 24 * s, vertical: 24 * s)
                  .add(EdgeInsets.only(bottom: bottomInset)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'OKEY',
                    style: TextStyle(
                      fontSize: 56 * s,
                      fontWeight: FontWeight.w900,
                      color: OkeyColors.accent,
                      letterSpacing: 6,
                      height: 1,
                      shadows: const [
                        Shadow(
                            color: OkeyColors.logoShadow, offset: Offset(0, 2))
                      ],
                    ),
                  ),
                  Text(
                    'ONLINE',
                    style: TextStyle(
                        fontSize: 18 * s,
                        letterSpacing: 10,
                        color: const Color(0xCCFFFFFF)),
                  ),
                  SizedBox(height: 24 * s),
                  OkeyPhotoPicker(
                      onChanged: (photo) => _photo = photo, size: 64 * s),
                  SizedBox(height: 8 * s),
                  Text(
                    'Profil fotoğrafın (isteğe bağlı) — diğer oyuncular görür',
                    style: TextStyle(color: OkeyColors.muted, fontSize: 12 * s),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14 * s),
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    maxLength: OkeyOnlineProvider.maxNameLength,
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
                        backgroundColor: OkeyColors.tileBackBg,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                      ),
                      onPressed: () {
                        final name = _validateName();
                        if (name == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                OkeyBotScreen(initialPlayerName: name),
                          ),
                        );
                      },
                      child: Text('🤖 Bilgisayara Karşı Oyna',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                  Container(height: 1, color: OkeyColors.divider),
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: OkeyColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                      ),
                      onPressed: () {
                        final name = _validateName();
                        if (name != null) {
                          provider.createGame(name, photo: _photo);
                        }
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
                        side: const BorderSide(
                            color: Color(0x55FFFFFF), width: 2),
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
                      ),
                      onPressed: () {
                        final name = _validateName();
                        if (name == null) return;
                        if (_codeController.text.trim().isEmpty) {
                          _toast('Oda kodunu gir.');
                          return;
                        }
                        provider.joinGame(_codeController.text, name,
                            photo: _photo);
                      },
                      child: Text('Oyuna Katıl',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14 * s)),
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  Text(
                    'Online ya da bilgisayara karşı · 2, 3 ya da 4 kişi · klasik okey',
                    style: TextStyle(color: OkeyColors.muted, fontSize: 14 * s),
                    textAlign: TextAlign.center,
                  ),
                  if (provider.error != null) ...[
                    SizedBox(height: 12 * s),
                    Text(
                      provider.error!,
                      style:
                          TextStyle(color: OkeyColors.error, fontSize: 14 * s),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  SizedBox(height: 16 * s),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(
                            color: Color(0x55FFFFFF), width: 2),
                        padding: EdgeInsets.symmetric(vertical: 14 * s),
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
