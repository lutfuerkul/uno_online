import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

/// Online oyunlarda oyuncuyu tanımlayan kimlik.
///
/// Kimlik, Firebase'in **anonim oturumundaki UID**'dir. Firestore kuralları
/// "yalnızca odadaki oyuncu yazabilir" kısıtını buna dayandırır: odanın
/// `players` listesindeki değerler bu UID'lerdir ve kural
/// `request.auth.uid in resource.data.players` diye kontrol eder
/// (bkz. `firestore.rules`).
///
/// Anonim oturum Firebase tarafından cihazda kalıcı saklanır; yani UID
/// uygulama yeniden açıldığında da aynı kalır. Eskiden her `Provider`
/// oluşumunda yeni bir UUID üretiliyordu.
class PlayerIdentity {
  const PlayerIdentity._();

  /// Açılışta bir kez çağrılır (bkz. `main.dart`). Zaten oturum varsa
  /// hiçbir şey yapmaz — her çağrıda yeni anonim kullanıcı üretilmesini
  /// önler.
  ///
  /// Başarısız olursa sessizce geçer: Firebase yapılandırılmamış, ağ yok ya
  /// da Console'da anonim giriş açılmamış olabilir. Bu durumda çevrimdışı
  /// (bilgisayara karşı) modlar normal çalışmaya devam eder; online modda
  /// sıkı kurallar devredeyse yazma reddedilir.
  static Future<void> ensureSignedIn() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) return;
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {
      // bkz. yukarıdaki not — çevrimdışı modlar etkilenmez.
    }
  }

  /// Bu cihazın oyuncu kimliği.
  ///
  /// Anonim oturum yoksa rastgele bir UUID'ye düşülür; böylece uygulama
  /// çökmez, ancak kimlik doğrulama isteyen kurallar altında online yazma
  /// reddedilir.
  static String current() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {
      // Firebase hiç başlatılamamışsa instance erişimi de hata verir.
    }
    return const Uuid().v4();
  }
}
