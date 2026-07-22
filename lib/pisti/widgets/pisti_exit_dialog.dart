import 'package:flutter/material.dart';

import '../theme/pisti_theme.dart';

/// Sistem geri tuşu/gesture'ıyla oyundan çıkmadan önce onay ister. Dönen
/// değer true ise kullanıcı çıkmayı onaylamıştır.
Future<bool> confirmLeavePistiGame(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PistiColors.topbar,
      title: const Text('Oyundan çık?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Oyundan çıkmak istediğine emin misin?',
        style: TextStyle(color: PistiColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: PistiColors.error),
          child: const Text('Çık'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
