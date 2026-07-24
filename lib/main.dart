import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/game_provider.dart';
import 'screens/game_select_screen.dart';
import 'services/update_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase henüz yapılandırılmadıysa (bkz. README) online oda kur/katıl
    // çalışmaz, ama bilgisayara karşı (çevrimdışı) modlar bundan etkilenmez.
  }
  runApp(const UnoApp());
}

class UnoApp extends StatelessWidget {
  const UnoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameProvider(),
      child: MaterialApp(
        title: 'uWin, Pişti & Okey',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFFD32F2F),
          useMaterial3: true,
        ),
        home: const _UpdateCheckGate(child: GameSelectScreen()),
      ),
    );
  }
}

/// Açılışta arka planda sürüm kontrolü yapar; yüklü sürüm eskiyse (bkz.
/// [UpdateCheckService]) kapatılabilir bir uyarı gösterir. Kontrol
/// başarısız olursa (internet yok vb.) sessizce vazgeçilir, uygulama
/// normal çalışmaya devam eder.
class _UpdateCheckGate extends StatefulWidget {
  final Widget child;
  const _UpdateCheckGate({required this.child});

  @override
  State<_UpdateCheckGate> createState() => _UpdateCheckGateState();
}

class _UpdateCheckGateState extends State<_UpdateCheckGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  Future<void> _checkForUpdate() async {
    final result = await UpdateCheckService.check();
    if (result == null || !result.updateAvailable || !mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Güncelleme mevcut'),
        content: const Text(
          'Telefonundaki sürüm eski. Yeni özellikler ve düzeltmeler için '
          'lütfen uygulamanın güncel sürümünü yükle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
