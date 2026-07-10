import 'package:firebase_core/firebase_core.dart';

/// GEÇİCİ ŞABLON — Firebase henüz bağlanmadı.
///
/// Bu dosyayı elle doldurma. Terminalde şu komutu çalıştırınca otomatik
/// oluşturulur ve bu dosyanın üzerine yazılır:
///
///   dart pub global activate flutterfire_cli
///   flutterfire configure
///
/// Ayrıntılı adımlar için README.md'ye bak.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'firebase_options.dart henüz oluşturulmadı.\n'
      'Terminalde "flutterfire configure" komutunu çalıştır; '
      'bu dosya gerçek Firebase ayarlarınla değiştirilecek.\n'
      'Ayrıntılar için README.md.',
    );
  }
}
