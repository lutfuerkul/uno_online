# Kart Oyunları: UNO + Pişti

Bu depo, **tek bir yüklenebilir web uygulaması** (PWA) olarak paketlenmiş iki
gerçek zamanlı çok oyunculu kart oyunu içerir. Siteyi telefonun ana ekranına
bir kez eklersin; açılışta **UNO** ya da **Pişti**'yi seçersin. Oyuncular
kendi telefonlarından bir oda kodu üzerinden buluşup oynar.

| Bölüm | Klasör | Ne işe yarar? |
|-------|--------|---------------|
| 🎴 Seçim ekranı | `docs/` | Siteyi açınca gördüğün ilk ekran — UNO ya da Pişti'yi seçersin. Ana ekrana eklenebilen tek uygulama burası. |
| 🌐 **UNO** (2-4 kişi) | `docs/uno/` | Klasik UNO, oda koduyla online. |
| 🃏 **Pişti** (2 ya da 4 kişi, takım yok) | `docs/pisti/` | Klasik iskambil kağıtlarıyla Pişti, oda koduyla online. |
| 📱 **Flutter** (UNO uygulaması) | `lib/` | Bilgisayarı olup APK derleyebilenler için ayrı bir UNO sürümü. |

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
- Açılışta kaç kişi olacağını seçersin — **UNO: 2/3/4**, **Pişti: 2/4** (sen +
  botlar).
- Oyun tamamen telefonda yerel çalışır; Firebase/oda kodu gerekmez, çevrimdışı
  bile oynanır.
- Botların zorluğu iki oyunda da benzer (orta seviye, mantıklı hamleler).
- **UNO'da** bilgisayara karşı oynarken tek kart kalınca **"UNO" otomatik**
  denir; ceza yemezsin.

---

## 🃏 Pişti kuralları

Klasik 52 kartlık iskambil destesiyle oynanan, 2 ya da 4 kişilik (takım yok,
herkes kendi başına) Pişti. Oyun **sadece 2 ya da 4 kişiyle** başlatılabilir
— 3 kişi bekleme odasında kalabilir ama "Oyunu Başlat" butonu 4. kişi
katılana (ya da biri ayrılıp 2 kişi kalana) kadar devre dışı olur (104 kart
3 kişiye tam bölünmediği için).

### Kurallar (özet)
- 2 oyuncuda tek 52 kartlık standart deste, 4 oyuncuda iki deste birleştirilip
  104 kartla oynanır. Her oyuncuya 4'er kart dağıtılır, masaya 4 kart açılır
  (açılan kartlar arasında vale çıkarsa deste yeniden karılır).
- Sırası gelen elinden bir kart oynar:
  - Masadaki üst kartla **aynı sayıdaysa** → masadaki bütün kartları alır.
  - **Vale** oynarsa → masa boş değilse bütün kartları alır (masa boşken vale
    sadece masaya konur, yakalama olmaz).
  - Eşleşme yoksa kart masaya konur, sıra rakibe geçer.
  - Masada **tek kart** varken eşleştirip yakalarsan bu bir **Pişti**'dir
    (bonus puan).
- Bir turdaki 4'er kart bitince, deste hâlâ doluysa herkese yeniden 4'er kart
  dağıtılır; deste de biterse oyun sona erer ve masada kalan kartlar son
  yakalayan oyuncuya yazılır.
- **Puanlama:** Her Pişti +10 · yakalanan her As +1 · Sinek 2'li +2 ·
  Karo 10'lu +3 · yakalanan her Vale +1 · en çok kart toplayan +3 (4 kişilik
  oyunda bu özel kartlardan ikişer tane olabilir, her biri ayrı puan getirir).
  En yüksek puan kazanır.

---

## 📱 Flutter sürümü (uygulama)

Aşağısı, bir bilgisayarda APK/iOS uygulaması olarak derlemek içindir.

## Nasıl çalışır?

Tüm oyun durumu (desteler, eller, sıra, geçerli renk) Firestore'da **tek bir
belgede** tutulur. İki telefon da bu belgeyi canlı dinler; biri kart oynayınca
belge güncellenir ve değişiklik anında diğer telefona yansır. Ayrı bir sunucu
kodu yoktur.

## Teknolojiler

| Paket | Görevi |
|-------|--------|
| `firebase_core`, `cloud_firestore` | Gerçek zamanlı çok oyunculu senkronizasyon |
| `provider` | Uygulama içi durum yönetimi |
| `uuid` | Benzersiz oyuncu ve kart kimlikleri |

## Proje yapısı

```
lib/
├── main.dart                     # Uygulama girişi + yönlendirme
├── firebase_options.dart         # (flutterfire configure ile oluşturulur)
├── models/
│   ├── uno_card.dart             # Kart modeli
│   └── game_state.dart           # Firestore belgesinin Dart karşılığı
├── services/
│   ├── deck_service.dart         # 108 kartlık deste + oynama kuralları
│   └── game_service.dart         # Firestore işlemleri (kur/katıl/oyna/çek)
├── providers/
│   └── game_provider.dart        # UI ↔ servis köprüsü
├── screens/
│   ├── home_screen.dart          # Oyun kur / katıl
│   └── game_screen.dart          # Bekleme odası + oyun tahtası + sonuç
└── widgets/
    └── card_widget.dart          # Kart görseli
```

## Kurulum

### 1. Flutter platform dosyalarını oluştur

Depoda yalnızca `lib/` ve `pubspec.yaml` var. Android/iOS klasörlerini üretmek
için proje kökünde şunu çalıştır (mevcut `lib/` ve `pubspec.yaml` korunur):

```bash
flutter create --org com.example --project-name uno_online .
```

### 2. Paketleri indir

```bash
flutter pub get
```

### 3. Firebase'i bağla

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

4. Firestore güvenlik kurallarını ayarla. Geliştirme için bu depodaki
   `firestore.rules` dosyasını Firebase Console → Firestore → Rules bölümüne
   yapıştırabilirsin. **Uyarı:** bu kurallar sadece geliştirme içindir,
   yayınlamadan önce sıkılaştır.

### 4. Çalıştır

İki farklı cihazda (veya emülatörde) çalıştır:

```bash
flutter run
```

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
