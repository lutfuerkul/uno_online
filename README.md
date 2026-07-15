# Kart Oyunları: UNO + Pişti

Bu depo, **tek bir yüklenebilir web uygulaması** (PWA) olarak paketlenmiş iki
gerçek zamanlı çok oyunculu kart oyunu içerir. Siteyi telefonun ana ekranına
bir kez eklersin; açılışta **UNO** ya da **Pişti**'yi seçersin. Oyuncular
kendi telefonlarından bir oda kodu üzerinden buluşup oynar.

| Bölüm | Klasör | Ne işe yarar? |
|-------|--------|---------------|
| 🎴 Seçim ekranı | `docs/` | Siteyi açınca gördüğün ilk ekran — UNO ya da Pişti'yi seçersin. Ana ekrana eklenebilen tek uygulama burası. |
| 🌐 **UNO** (2-4 kişi) | `docs/uno/` | Klasik UNO, oda koduyla online. |
| 🃏 **Pişti** (2, 3 ya da 4 kişi, takım yok) | `docs/pisti/` | Klasik iskambil kağıtlarıyla Pişti, oda koduyla online. |
| 📱 **Flutter** (UNO + Pişti uygulaması) | `lib/` | Bilgisayarı olup APK derleyebilenler için: UNO ve Pişti, ikisi de online (oda koduyla) ve bilgisayara karşı modlarla. |

---

## 🌐 Web sürümü — sadece telefonla (bilgisayar gerekmez)

Tamamen tarayıcıda çalışır; GitHub Pages'te ücretsiz barınır. Tek bir
uygulama olarak yüklenir, içinde iki oyun olur. Yapman gerekenler:

### 1. Firebase projesi aç (telefon tarayıcısından)
1. **console.firebase.google.com** → yeni proje oluştur.
2. **Firestore Database → Create database** (test modunda başlat).
3. Proje Ayarları (dişli) → aşağı in → **Web uygulaması ekle** (`</>` simgesi).
   Sana `apiKey`, `projectId`... içeren bir "config" verecek.

### 2. Ayarları yapıştır (GitHub'da telefondan)
1. `docs/uno/firebase-config.js` dosyasını aç → **kalem** (düzenle) simgesi →
   `BURAYA_YAPISTIR` yazan yerleri Firebase'in verdiği değerlerle değiştir →
   **Commit changes**.
2. `docs/pisti/firebase-config.js` dosyası varsayılan olarak UNO ile **aynı
   Firebase projesini** kullanacak şekilde zaten dolduruldu (Pişti kendi
   `pisti_games` koleksiyonunu kullanır). Farklı bir proje kullanmak
   istersen buradaki değerleri de kendi projeninkiyle değiştir.
3. Firebase Console → **Firestore Database → Rules** bölümüne bu depodaki
   `firestore.rules` dosyasının içeriğini yapıştır (hem `games` hem
   `pisti_games` koleksiyonlarına izin verir).

### 3. GitHub Pages'i aç
1. Depoda **Settings → Pages**.
2. Source: **Deploy from a branch** → Branch: bu dal, klasör: **/docs** → Save.
3. 1-2 dakika sonra bir link çıkar (örn. `https://KULLANICI.github.io/uno_online/`).

### 4. Yükle ve oyna
1. Linki telefonda aç, tarayıcı menüsünden **"Ana ekrana ekle"** de — tek bir
   "Kart Oyunları" ikonu eklenir.
2. Uygulamayı açınca **UNO** ya da **Pişti**'yi seç.
3. **Online:** "Yeni Oyun Kur" de, çıkan kodu arkadaşına gönder; o da aynı
   ekrandan aynı oyunu seçip "Oyuna Katıl" ile kodu girsin. Herkes kendi
   telefonundan oynar. 🎉

### 🤖 Bilgisayara karşı (tek başına, internet/Firebase gerekmez)
Her iki oyunda da ana ekranda **"🤖 Bilgisayara Karşı Oyna"** butonu var:
- Açılışta kaç kişi olacağını seçersin — **UNO: 2/3/4**, **Pişti: 2/3/4** (sen +
  botlar).
- Oyun tamamen telefonda yerel çalışır; Firebase/oda kodu gerekmez, çevrimdışı
  bile oynanır.
- Botların zorluğu iki oyunda da benzer (orta seviye, mantıklı hamleler).
- **UNO'da** bilgisayara karşı oynarken tek kart kalınca **"UNO" otomatik**
  denir; ceza yemezsin.

---

## 🃏 Pişti kuralları

Klasik 52 kartlık iskambil destesiyle oynanan, 2, 3 ya da 4 kişilik (takım
yok, herkes kendi başına) Pişti.

### Kurallar (özet)
- 2 oyuncuda tek 52 kartlık standart deste; 3 ve 4 oyuncuda iki deste
  birleştirilip 104 kartla oynanır. Her oyuncuya 4'er kart dağıtılır.
- **İlk açılışta masaya kart konur:** 2 ve 4 kişilik oyunda 3 kapalı + 1 açık
  (4 kart); **3 kişilik oyunda 4 kapalı + 1 açık** (5 kart). Yüzü açık kart
  hiçbir zaman vale olmaz; kapalı kartlar vale/puanlı olabilir ve o desteyi
  **kim yakalarsa** kapalı kartların puanları da onun puanına eklenir.
- İlk açılışta yüzü açık kartla oyuncunun elindeki kart eşleşirse **pişti
  sayılmaz** (masada birden fazla kart olduğu için); sadece yakalanan kartların
  puanları hesaplanır.
- Sırası gelen elinden bir kart oynar:
  - Masadaki üst kartla **aynı sayıdaysa** → masadaki bütün kartları alır.
  - **Vale** oynarsa → masa boş değilse bütün kartları alır (masa boşken vale
    sadece masaya konur, yakalama olmaz).
  - Eşleşme yoksa kart masaya konur, sıra rakibe geçer.
  - Masada **tek kart** varken eşleştirip yakalarsan bu bir **Pişti**'dir
    (bonus puan).
  - Yakalarken atılan kart **önce masada görünür**, kısa bir an sonra tüm
    deste yakalayan oyuncuya toplanır (herkes atılan kartı rahatça görsün).
- Bir turdaki 4'er kart bitince, deste hâlâ doluysa yeniden dağıtılır. Kartlar
  oyunculara **eşit** dağıtılır: 2 kişide her el 4'er, 4 kişide **son el 5'er**
  kart olur (104 kart 4 oyuncuya tam bölünür — herkes 25 kart oynar); 3 kişide
  de aynı şekilde **son el 5'er** kart olur (herkes 33 kart oynar). Deste
  bitince oyun sona erer ve masada kalan kartlar son yakalayana yazılır.
- **Puanlama:** Her Pişti +10 · yakalanan her As +1 · Sinek 2'li +2 ·
  Karo 10'lu +3 · yakalanan her Vale +1 · en çok kart toplayan +3 (3 ve 4
  kişilik oyunda bu özel kartlardan ikişer tane olabilir, her biri ayrı puan
  getirir). En yüksek puan kazanır.

---

## 📱 Flutter sürümü (uygulama)

Aşağısı, bir bilgisayarda APK/iOS uygulaması olarak derlemek içindir.

### 🤖 Bilgisayara karşı (internet gerekmez)

Açılışta UNO ya da Pişti'yi seçtikten sonra ana ekranda **"Bilgisayara Karşı
Oyna"** seçeneği var: 2, 3 ya da 4 kişi (sen + botlar) seçip tamamen cihaz
içinde, internet ya da Firebase olmadan oynayabilirsin. Bot kartları basit
kural tabanlı bir mantıkla seçer (rakip(ler)in eli azaldıkça saldırgan
kartları öne çıkarır, jokerleri/valeyi mümkün olduğunca saklar).

### 🌐 Online (oda koduyla, 2-4 kişi)

Hem UNO hem Pişti'de artık oda koduyla online çok oyuncululuk var: bir oyuncu
"Yeni Oyun Kur" der, çıkan 5 haneli kodu paylaşır; diğerleri "Oyuna Katıl"
ile aynı koda girer. 2-4 kişi katılınca **kurucu** "Oyunu Başlat" der ve oyun
başlar. Görsel ve kurallar (UNO'da bloklama/reverse kilidi/hedef seçimi,
Pişti'de pişti/vale yakalama, puanlama) web sürümüyle birebir aynıdır.

## Nasıl çalışır?

**Online** modda tüm oyun durumu (desteler, eller, sıra, skorlar...)
Firestore'da **tek bir belgede** tutulur. Her cihaz bu belgeyi canlı dinler;
biri hamle yapınca belge güncellenir ve değişiklik anında diğerlerine
yansır. Ayrı bir sunucu kodu yoktur.

**Bilgisayara karşı** modlarda (hem UNO hem Pişti) aynı kurallar cihaz
içinde, Firestore'a hiç dokunmadan çalışır; botların hamleleri kısa bir
gecikmeyle otomatik oynanır.

## Teknolojiler

| Paket | Görevi |
|-------|--------|
| `firebase_core`, `cloud_firestore` | Gerçek zamanlı çok oyunculu senkronizasyon |
| `provider` | Uygulama içi durum yönetimi |
| `uuid` | Benzersiz oyuncu ve kart kimlikleri |

## Proje yapısı

```
lib/
├── main.dart                       # Uygulama girişi + oyun seçim ekranı
├── firebase_options.dart           # (flutterfire configure ile oluşturulur)
├── theme/
│   └── uno_theme.dart               # docs/uno CSS ile birebir eşleşen renkler
├── models/
│   ├── uno_card.dart                 # UNO kart modeli
│   ├── game_state.dart               # Oyun durumu (online + yerel ortak)
│   └── uno_board_controller.dart     # Online/yerel tahtanın paylaştığı arayüz
├── services/
│   ├── deck_service.dart            # 108 kartlık deste + oynama kuralları
│   ├── uno_engine.dart              # Tur/kural motoru (online ve yerel ortak)
│   ├── game_service.dart            # Firestore işlemleri (kur/katıl/başlat/oyna/pas)
│   └── uno_bot_service.dart         # UNO bot yapay zekası
├── providers/
│   ├── game_provider.dart           # Online UNO: UI ↔ Firestore köprüsü
│   └── local_uno_provider.dart      # Bilgisayara karşı UNO motoru
├── screens/
│   ├── game_select_screen.dart      # Açılış: UNO ya da Pişti seç
│   ├── uno_root_screen.dart         # Online UNO: giriş/oyun ekranı yönlendirmesi
│   ├── home_screen.dart             # Online UNO: kur / katıl / bilgisayara karşı
│   ├── game_screen.dart             # Online UNO: bekleme odası + tahta + sonuç
│   └── uno_bot_screen.dart          # Bilgisayara karşı UNO: oyuncu sayısı + tahta
├── widgets/
│   ├── card_widget.dart             # UNO kart görseli (web ile birebir)
│   ├── uno_symbol_painter.dart      # Skip/Reverse/+2/Joker sembolleri (CustomPaint)
│   ├── uno_board_view.dart          # Paylaşılan tahta (online + yerel ortak)
│   └── uno_result_view.dart         # Paylaşılan sonuç ekranı
└── pisti/                           # Pişti — online + bilgisayara karşı
    ├── theme/
    │   └── pisti_theme.dart          # docs/pisti CSS ile birebir eşleşen renkler
    ├── models/
    │   ├── pisti_card.dart
    │   ├── pisti_game_state.dart
    │   └── pisti_board_controller.dart
    ├── services/
    │   ├── pisti_deck_service.dart   # Deste, dağıtım, puanlama
    │   ├── pisti_engine.dart         # Tur/kural motoru (online ve yerel ortak)
    │   ├── pisti_game_service.dart   # Firestore işlemleri
    │   └── pisti_bot_service.dart    # Pişti bot yapay zekası
    ├── providers/
    │   ├── pisti_online_provider.dart
    │   └── pisti_local_provider.dart
    ├── screens/
    │   ├── pisti_root_screen.dart
    │   ├── pisti_home_screen.dart    # kur / katıl / bilgisayara karşı
    │   ├── pisti_game_screen.dart    # bekleme odası + tahta + sonuç (online)
    │   └── pisti_bot_screen.dart     # oyuncu sayısı + tahta (bilgisayara karşı)
    └── widgets/
        ├── pisti_card_widget.dart    # İskambil kağıdı görseli (web ile birebir)
        ├── pisti_court_painter.dart  # Vale/Kız/Papaz figürü (CustomPaint)
        ├── pisti_back_pattern_painter.dart
        ├── pisti_board_view.dart     # Paylaşılan tahta (online + yerel ortak)
        └── pisti_result_view.dart    # Paylaşılan puan tablosu ekranı
```

## Kurulum

### 1. Paketleri indir

`android/` klasörü depoda hazır (Android APK derlemek için gereken Gradle/
Kotlin dosyaları). Sadece paketleri indirmen yeterli:

```bash
flutter pub get
```

(iOS ya da masaüstü gibi başka platformlar da istersen: `flutter create
--platforms=ios .` gibi eksik platformu ekleyebilirsin; mevcut `lib/` ve
`android/` korunur.)

### 2. Firebase'i bağla (yalnızca online oyun için gerekli)

`lib/firebase_options.dart` şu an bir şablon; bağlanmadan da uygulama açılır
ve **bilgisayara karşı (çevrimdışı)** modlar sorunsuz çalışır — sadece "Yeni
Oyun Kur" / "Oyuna Katıl" (online) çalışmaz. Online oyunu da istiyorsan:

1. [Firebase Console](https://console.firebase.google.com)'da yeni bir proje
   oluştur.
2. **Firestore Database**'i başlat (test modunda başlatabilirsin).
3. FlutterFire CLI'yi kur ve projeyi yapılandır:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Bu komut, şablon olan `lib/firebase_options.dart` dosyasının üzerine gerçek
   ayarları yazar.

4. Firestore güvenlik kurallarını ayarla: bu depodaki `firestore.rules`
   dosyasını Firebase Console → Firestore → Rules bölümüne yapıştır. Bu
   kurallar oda silinmesini engeller ve her yazmanın uygulamanın beklediği
   alan/tip şekliyle eşleşmesini zorunlu kılar. **Not:** Auth eklenmediği
   için "sadece sıradaki oyuncu yazabilsin" gibi kimlik bazlı bir kontrol
   yok — bunun için Firebase Authentication eklemek gerekir.

### 3. Çalıştır (geliştirme sırasında)

Bir cihazda (veya emülatörde) çalıştır:

```bash
flutter run
```

### 4. APK al

**Bilgisayarın yoksa / Android SDK kurmak istemiyorsan:** Bu depoda
`.github/workflows/build-apk.yml` adında bir GitHub Actions iş akışı var.
`main` dalına her push'ta (ya da Actions sekmesinden elle "Run workflow" ile)
APK'yı GitHub'ın kendi sunucularında derler; bittiğinde **Actions → ilgili
çalıştırma → Artifacts** bölümünden `uno-pisti-debug-apk` dosyasını
indirebilirsin. Bilgisayarına Flutter/Android SDK kurmana gerek kalmaz.

**Kendi bilgisayarında derlemek istersen:** Android SDK'yı (Android Studio
üzerinden ya da `sdkmanager` ile) kurup şunu çalıştır:

```bash
flutter build apk --debug
```

APK, `build/app/outputs/flutter-apk/app-debug.apk` yolunda oluşur; telefona
kopyalayıp "bilinmeyen kaynaklardan yükle" izniyle kurabilirsin.

## Nasıl oynanır?

1. Bir oyuncu **"Yeni Oyun Kur"** der, ekranda 5 haneli bir oda kodu çıkar.
2. Diğer oyuncu bu kodu **"Oyuna Katıl"** ile girer.
3. İkinci oyuncu katılınca kartlar dağıtılır ve oyun başlar.
4. Sırası gelen oyuncu, açık karta renk/sayı bakımından uyan bir kart oynar ya
   da desteden kart çeker. Elini ilk bitiren kazanır.

## Kurallar (2 kişilik)

- `Skip`, `Reverse`, `+2`, `+4` oynayınca sıra tekrar sana döner (rakip atlanır).
- `+2` / `+4` oynanınca rakip ilgili sayıda kart çeker.
- Joker (`JOKER` / `+4`) oynayınca renk seçersin.

## Yol haritası (sonraki adımlar)

- [ ] "UNO!" deme mekaniği ve tek kart cezası
- [ ] Firebase Authentication + güvenli Firestore kuralları (hile engeli)
- [ ] Yeniden oynama / rövanş
- [ ] 2'den fazla oyuncu desteği
- [ ] Kart animasyonları ve ses
