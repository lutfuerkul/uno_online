import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/player_photo_store.dart';
import '../theme/okey_theme.dart';
import 'okey_photo_frame.dart';

/// Oyun kurulum ekranlarında (bilgisayara karşı / online) kullanıcının kendi
/// profil fotoğrafını galeriden seçmesini sağlar. Daha önce kaydedilmiş
/// fotoğrafı otomatik yükler; seçilen yeni fotoğraf hem cihazda kalıcı olarak
/// saklanır hem de [onChanged] ile üst widget'a (oyun kurulurken
/// gönderilmesi için) bildirilir.
class OkeyPhotoPicker extends StatefulWidget {
  final ValueChanged<String?> onChanged;
  final double size;

  const OkeyPhotoPicker({super.key, required this.onChanged, this.size = 64});

  @override
  State<OkeyPhotoPicker> createState() => _OkeyPhotoPickerState();
}

class _OkeyPhotoPickerState extends State<OkeyPhotoPicker> {
  String? _photo;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await PlayerPhotoStore.loadOkeyPhoto();
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
      await PlayerPhotoStore.saveOkeyPhoto(base64Photo);
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
    return GestureDetector(
      onTap: _pick,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          OkeyPhotoFrame(base64Photo: _photo, size: widget.size),
          if (_loading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x88000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: OkeyColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt, size: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
