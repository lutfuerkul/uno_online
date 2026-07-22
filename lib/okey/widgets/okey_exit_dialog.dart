import 'package:flutter/material.dart';

import '../theme/okey_theme.dart';

/// Sistem geri tuşu/gesture'ıyla oyundan çıkmadan önce onay ister. Dönen
/// değer true ise kullanıcı çıkmayı onaylamıştır.
Future<bool> confirmLeaveOkeyGame(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: OkeyColors.topbar,
      title: const Text('Oyundan çık?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Oyundan çıkmak istediğine emin misin?',
        style: TextStyle(color: OkeyColors.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Vazgeç', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: OkeyColors.error),
          child: const Text('Çık'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
