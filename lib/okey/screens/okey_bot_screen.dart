import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/ui_scale.dart';
import '../providers/okey_local_provider.dart';
import '../theme/okey_theme.dart';
import '../widgets/okey_board_view.dart';
import '../widgets/okey_exit_dialog.dart';
import '../widgets/okey_hand_reveal_view.dart';
import '../widgets/okey_photo_picker.dart';
import '../widgets/okey_result_view.dart';

/// "Bilgisayara Karşı Oyna" akışı: önce oyuncu sayısı seçilir, sonra tahta
/// gösterilir.
class OkeyBotScreen extends StatelessWidget {
  const OkeyBotScreen({super.key, this.initialPlayerName});

  final String? initialPlayerName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OkeyLocalProvider(),
      child: Consumer<OkeyLocalProvider>(
        builder: (context, provider, _) {
          // Bir oyun başladıysa sistem geri tuşu doğrudan çıkmasın; onay
          // ister. Henüz kurulum ekranındaysa (oyun yok) normal geri çalışır.
          final inGame = provider.state != null;
          return PopScope(
            canPop: !inGame,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop) return;
              final leave = await confirmLeaveOkeyGame(context);
              if (leave) provider.leaveGame();
            },
            child: Scaffold(
              backgroundColor: OkeyColors.background,
              body: SafeArea(
                child: _OkeyBotRoot(initialPlayerName: initialPlayerName),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OkeyBotRoot extends StatelessWidget {
  const _OkeyBotRoot({this.initialPlayerName});

  final String? initialPlayerName;

  @override
  Widget build(BuildContext context) {
    final started =
        context.select<OkeyLocalProvider, bool>((p) => p.state != null);
    return started
        ? const _LocalGameBody()
        : _OkeyBotSetupForm(initialPlayerName: initialPlayerName);
  }
}

class _LocalGameBody extends StatefulWidget {
  const _LocalGameBody();

  @override
  State<_LocalGameBody> createState() => _LocalGameBodyState();
}

class _LocalGameBodyState extends State<_LocalGameBody> {
  /// Kazanan varsa eli birkaç saniye gösterilir; berabere ise kısa gecikmeyle
  /// doğrudan skor ekranına geçilir.
  static const _handRevealDuration = Duration(seconds: 7);
  static const _drawDelay = Duration(milliseconds: 1600);

  Timer? _resultTimer;
  bool _showResult = false;

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OkeyLocalProvider>();
    final state = provider.state;
    final finished = state?.status == 'finished';

    if (finished) {
      final s = state!;
      final hasWinner = s.winner != null || s.winners.isNotEmpty;
      _resultTimer ??=
          Timer(hasWinner ? _handRevealDuration : _drawDelay, () {
        if (mounted) setState(() => _showResult = true);
      });
      if (_showResult) {
        return OkeyResultView(
          controller: provider,
          onRematch: provider.rematch,
          onLeave: () => provider.leaveGame(),
        );
      }
      if (hasWinner) {
        return OkeyHandRevealView(controller: provider, state: s);
      }
    } else {
      _resultTimer?.cancel();
      _resultTimer = null;
      _showResult = false;
    }

    return OkeyBoardView(
      controller: provider,
      roomLabel: '🤖 Bilgisayara Karşı',
      onLeave: () => provider.leaveGame(),
    );
  }
}

class _OkeyBotSetupForm extends StatefulWidget {
  const _OkeyBotSetupForm({this.initialPlayerName});

  final String? initialPlayerName;

  @override
  State<_OkeyBotSetupForm> createState() => _OkeyBotSetupFormState();
}

class _OkeyBotSetupFormState extends State<_OkeyBotSetupForm> {
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
    context.read<OkeyLocalProvider>().startGame(
          playerName: _nameController.text.trim(),
          totalPlayers: total,
          photo: _photo,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Bu kurulum ekranının zemin tonu UNO'nunkiyle aynı (#1B2430) —
    // yalnızca bu ekran için; oyun içi renkler (OkeyColors) değişmedi.
    // Tüm ölçüler tahtalardaki tek-katsayı yaklaşımıyla (bkz. computeUiScale)
    // ekrana göre orantılı ölçeklenir.
    return Container(
      color: const Color(0xFF1B2430),
      child: LayoutBuilder(builder: (context, constraints) {
        final s = computeUiScale(constraints);
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24 * s),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🤖', style: TextStyle(fontSize: 44 * s)),
                SizedBox(height: 8 * s),
                Text(
                  'Bilgisayara Karşı Okey',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20 * s,
                      fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 16 * s),
                OkeyPhotoPicker(
                    onChanged: (photo) => _photo = photo, size: 64 * s),
                SizedBox(height: 16 * s),
                Text(
                  'Kaç kişi olsun? (sen + bilgisayarlar)',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 14 * s),
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
                      fillColor: OkeyColors.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12 * s),
                        borderSide: const BorderSide(
                            color: OkeyColors.inputBorder, width: 2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * s),
                ],
                SizedBox(
                  width: 280 * s,
                  child: Column(
                    children: [
                      for (final n in [2, 3, 4]) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: n == 4
                                  ? OkeyColors.accent
                                  : OkeyColors.primary,
                              foregroundColor:
                                  n == 4 ? Colors.black : Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14 * s),
                            ),
                            onPressed: () => _start(n),
                            child: Text(
                              n == 4
                                  ? '4 Oyuncu (klasik) — sen + 3 bot'
                                  : '$n Oyuncu (sen + ${n - 1} bot)',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14 * s),
                            ),
                          ),
                        ),
                        SizedBox(height: 12 * s),
                      ],
                    ],
                  ),
                ),
                Text(
                  'Klasik okey 4 kişiyle oynanır; 2–3 kişilik de mümkün.',
                  style: TextStyle(color: OkeyColors.muted, fontSize: 13 * s),
                  textAlign: TextAlign.center,
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
