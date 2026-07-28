import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/player_photo_store.dart';
import '../../theme/ui_scale.dart';
import '../../widgets/player_photo_picker.dart';
import '../providers/pisti_local_provider.dart';
import '../theme/pisti_theme.dart';
import '../widgets/pisti_board_view.dart';
import '../widgets/pisti_exit_dialog.dart';
import '../widgets/pisti_result_view.dart';

/// "Bilgisayara Karşı Oyna" akışını yönetir: önce oyuncu sayısı seçilir
/// (`docs/pisti/game.js` `renderLocalSetup()` ile birebir aynı), sonra web
/// ile aynı tahta ([PistiBoardView]) gösterilir.
class PistiBotScreen extends StatelessWidget {
  const PistiBotScreen({super.key, this.initialPlayerName});

  /// Ana ekranda girilen isim; doluysa kurulumda tekrar sorulmaz.
  final String? initialPlayerName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PistiLocalProvider(),
      child: Consumer<PistiLocalProvider>(
        builder: (context, provider, _) {
          // Bir oyun başladıysa sistem geri tuşu doğrudan çıkmasın; onay
          // ister. Henüz kurulum ekranındaysa (oyun yok) normal geri çalışır.
          final inGame = provider.state != null;
          return PopScope(
            canPop: !inGame,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final leave = await confirmLeavePistiGame(context);
              if (leave) provider.leaveGame();
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: PistiColors.background,
              body: SafeArea(
                  child: _PistiBotRoot(initialPlayerName: initialPlayerName)),
            ),
          );
        },
      ),
    );
  }
}

class _PistiBotRoot extends StatelessWidget {
  const _PistiBotRoot({this.initialPlayerName});

  final String? initialPlayerName;

  @override
  Widget build(BuildContext context) {
    final started =
        context.select<PistiLocalProvider, bool>((p) => p.state != null);
    return started
        ? const _LocalGameBody()
        : _PistiBotSetupForm(initialPlayerName: initialPlayerName);
  }
}

class _LocalGameBody extends StatefulWidget {
  const _LocalGameBody();

  @override
  State<_LocalGameBody> createState() => _LocalGameBodyState();
}

class _LocalGameBodyState extends State<_LocalGameBody> {
  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PistiLocalProvider>();
    final finished = provider.state?.status == 'finished';

    if (finished) {
      _resultTimer ??= Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showResult = true);
      });
      if (_showResult) {
        return PistiResultView(
          controller: provider,
          onRematch: provider.rematch,
          onLeave: () => provider.leaveGame(),
        );
      }
    } else {
      _resultTimer?.cancel();
      _resultTimer = null;
      _showResult = false;
    }

    return PistiBoardView(
      controller: provider,
      roomLabel: '🤖 Bilgisayara Karşı',
      onLeave: () => provider.leaveGame(),
    );
  }
}

class _PistiBotSetupForm extends StatefulWidget {
  const _PistiBotSetupForm({this.initialPlayerName});

  final String? initialPlayerName;

  @override
  State<_PistiBotSetupForm> createState() => _PistiBotSetupFormState();
}

class _PistiBotSetupFormState extends State<_PistiBotSetupForm> {
  late final TextEditingController _nameController;
  String? _photo;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialPlayerName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _showNameField => (widget.initialPlayerName ?? '').trim().isEmpty;

  void _start(int total) {
    context.read<PistiLocalProvider>().startGame(
          playerName: _nameController.text.trim(),
          totalPlayers: total,
          photo: _photo,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Bu kurulum ekranının zemin tonu UNO'nunkiyle aynı (#1B2430) —
    // yalnızca bu ekran için; oyun içi renkler (PistiColors) değişmedi.
    // Tüm ölçüler tahtalardaki tek-katsayı yaklaşımıyla (bkz. computeUiScale)
    // ekrana göre orantılı ölçeklenir.
    return Container(
      color: const Color(0xFF1B2430),
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
                Text('🤖', style: TextStyle(fontSize: 44 * s)),
                SizedBox(height: 8 * s),
                Text(
                  'Bilgisayara Karşı',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * s,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 16 * s),
                PlayerPhotoPicker(
                  onChanged: (photo) => _photo = photo,
                  loadSaved: PlayerPhotoStore.loadPistiPhoto,
                  saveNew: PlayerPhotoStore.savePistiPhoto,
                  borderColor: PistiColors.primary,
                  backgroundColor: PistiColors.hand,
                  badgeColor: PistiColors.primary,
                  size: 64 * s,
                ),
                SizedBox(height: 16 * s),
                Text(
                  'Kaç kişi olsun? (sen + bilgisayarlar)',
                  style: TextStyle(color: PistiColors.muted, fontSize: 14 * s),
                ),
                if (_showNameField) ...[
                  SizedBox(height: 16 * s),
                  TextField(
                    controller: _nameController,
                    textAlign: TextAlign.center,
                    maxLength: 8,
                    style: TextStyle(color: Colors.white, fontSize: 14 * s),
                    decoration: InputDecoration(
                      hintText: 'İsmin (opsiyonel)',
                      hintStyle: TextStyle(
                          color: const Color(0x66FFFFFF), fontSize: 14 * s),
                      counterText: '',
                      filled: true,
                      fillColor: PistiColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * s),
                        borderSide: const BorderSide(
                            color: PistiColors.inputBorder, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                ],
                SizedBox(
                  width: 260 * s,
                  child: Column(
                    children: [
                      for (final n in [2, 3, 4]) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PistiColors.primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14 * s),
                            ),
                            onPressed: () => _start(n),
                            child: Text('$n Oyuncu (sen + ${n - 1} bot)',
                                style: TextStyle(fontSize: 14 * s)),
                          ),
                        ),
                        SizedBox(height: 12 * s),
                      ],
                    ],
                  ),
                ),
                Text(
                  'Pişti 2, 3 ya da 4 kişiyle oynanır.',
                  style: TextStyle(color: PistiColors.muted, fontSize: 13 * s),
                ),
                SizedBox(height: 16 * s),
                SizedBox(
                  width: 200 * s,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:
                          const BorderSide(color: Color(0x55FFFFFF), width: 2),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Geri', style: TextStyle(fontSize: 14 * s)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
