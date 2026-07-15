import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase ayarları — web sürümündeki `docs/uno/firebase-config.js` ile aynı
/// proje: `unoonline-27104`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions Linux için yapılandırılmadı.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions bu platform için yapılandırılmadı.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA',
    appId: '1:794492266221:web:d5edddbd5899f9490b4ee4',
    messagingSenderId: '794492266221',
    projectId: 'unoonline-27104',
    authDomain: 'unoonline-27104.firebaseapp.com',
    storageBucket: 'unoonline-27104.firebasestorage.app',
  );

  /// Android APK — Firestore için web ile aynı Firebase projesi.
  /// Firebase Console'da `com.example.uno_online` paket adıyla Android
  /// uygulaması eklenmişse `flutterfire configure` ile güncel appId alınabilir.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA',
    appId: '1:794492266221:web:d5edddbd5899f9490b4ee4',
    messagingSenderId: '794492266221',
    projectId: 'unoonline-27104',
    storageBucket: 'unoonline-27104.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA',
    appId: '1:794492266221:web:d5edddbd5899f9490b4ee4',
    messagingSenderId: '794492266221',
    projectId: 'unoonline-27104',
    storageBucket: 'unoonline-27104.firebasestorage.app',
    iosBundleId: 'com.example.unoOnline',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA',
    appId: '1:794492266221:web:d5edddbd5899f9490b4ee4',
    messagingSenderId: '794492266221',
    projectId: 'unoonline-27104',
    storageBucket: 'unoonline-27104.firebasestorage.app',
    iosBundleId: 'com.example.unoOnline',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA',
    appId: '1:794492266221:web:d5edddbd5899f9490b4ee4',
    messagingSenderId: '794492266221',
    projectId: 'unoonline-27104',
    authDomain: 'unoonline-27104.firebaseapp.com',
    storageBucket: 'unoonline-27104.firebasestorage.app',
  );
}
