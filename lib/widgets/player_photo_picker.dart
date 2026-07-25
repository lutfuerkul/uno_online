import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'player_photo_frame.dart';

/// Oyun kurulum ekranlarında kullanıcının kendi profil fotoğrafını galeriden
/// seçmesini sağlar. [loadSaved] ile daha önce kaydedilmiş fotoğrafı otomatik
/// yükler; seçilen yeni fotoğraf [saveNew] ile cihazda kalıcı olarak
/// saklanır ve [onChanged] ile üst widget'a (oyun kurulurken gönderilmesi
/// için) bildirilir. UNO/Pişti/Okey arasında paylaşılan, temadan bağımsız
/// widget.
class PlayerPhotoPicker extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final Future<String?> Function() loadSaved;
  final Future<void> Function(String? base64Jpeg) saveNew;
  final Color borderColor;
  final Color backgroundColor;
  final Color badgeColor;
  final double size;

  const PlayerPhotoPicker({
    super.key,
    required this.onChanged,
    required this.loadSaved,
    required this.saveNew,
    required this.borderColor,
    required this.backgroundColor,
    required this.badgeColor,
    this.size = 64,
  });

  @override
  State<PlayerPhotoPicker> createState() => _PlayerPhotoPickerState();
}

class _PlayerPhotoPickerState extends State<PlayerPhotoPicker> {
  String? _photo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await widget.loadSaved();
    if (!mounted || saved == null) return;
    setState(() => _photo = saved);
    widget.onChanged(saved);
  }

  Future<void> _pick() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final base64Photo = base64Encode(bytes);
      await widget.saveNew(base64Photo);
      if (!mounted) return;
      setState(() => _photo = base64Photo);
      widget.onChanged(base64Photo);
    } catch (_) {
      // Kullanıcı seçimi iptal etti ya da izin verilmedi; sessizce geç.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Yükleniyor göstergesi ve kamera rozeti de [size] ile orantılı büyüyüp
    // küçülür (referans: 64px'lik fotoğrafta 18/3/12 px) — böylece seçici
    // dar/geniş ekranda tek parça gibi ölçeklenir.
    final size = widget.size;
    final spinner = size * 18 / 64;
    final badgePadding = size * 3 / 64;
    final badgeIcon = size * 12 / 64;
    final badgeOffset = size * -4 / 64;

    return GestureDetector(
      onTap: _pick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PlayerPhotoFrame(
            base64Photo: _photo,
            size: size,
            borderColor: widget.borderColor,
            backgroundColor: widget.backgroundColor,
          ),
          if (_loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: SizedBox(
                    width: spinner,
                    height: spinner,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            right: badgeOffset,
            bottom: badgeOffset,
            child: Container(
              padding: EdgeInsets.all(badgePadding),
              decoration: BoxDecoration(
                color: widget.badgeColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt,
                  size: badgeIcon, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
