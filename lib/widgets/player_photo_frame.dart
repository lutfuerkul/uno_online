import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Bir oyuncunun profil fotoğrafını çerçeve içinde gösterir; fotoğraf yoksa
/// (ya da çözülemiyorsa) soluk bir silüet ikonu gösterir. UNO/Pişti/Okey
/// arasında paylaşılan, temadan bağımsız (renkleri parametre alan) widget.
class PlayerPhotoFrame extends StatelessWidget {
  final String? base64Photo;
  final double size;
  final Color borderColor;
  final Color backgroundColor;

  const PlayerPhotoFrame({
    super.key,
    required this.base64Photo,
    required this.borderColor,
    required this.backgroundColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    final photo = base64Photo;
    if (photo != null && photo.isNotEmpty) {
      try {
        bytes = base64Decode(photo);
      } catch (_) {
        bytes = null;
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : Icon(Icons.person, color: const Color(0x88FFFFFF), size: size * 0.6),
    );
  }
}
