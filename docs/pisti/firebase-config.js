// ============================================================
//  Firebase ayarları (Firebase Console'dan alındı)
// ============================================================
// Not: Bu değerler (apiKey dahil) Firebase web uygulamalarında gizli
// değildir; herkese açık olması normaldir. Güvenlik Firestore
// kurallarıyla sağlanır.
//
// UNO ile aynı Firebase projesi kullanılıyor (bkz. docs/uno/firebase-config.js).
// Pişti "pisti_games" adında ayrı bir koleksiyon kullanır; bu yüzden
// Firestore kurallarına o koleksiyonu da eklemen gerekir — bkz. README'deki
// "Pişti" bölümü ve depo kökündeki firestore.rules dosyası.
window.FIREBASE_CONFIG = {
  apiKey: "AIzaSyDB8H-fTzpzVoCyEzGzjvUh57iH8Lh52zA",
  authDomain: "unoonline-27104.firebaseapp.com",
  projectId: "unoonline-27104",
  storageBucket: "unoonline-27104.firebasestorage.app",
  messagingSenderId: "794492266221",
  appId: "1:794492266221:web:d5edddbd5899f9490b4ee4",
};
