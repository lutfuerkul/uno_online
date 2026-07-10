# UNO Online

Çok oyunculu (şimdilik 2 kişilik) online UNO oyunu. İki oyuncu kendi
telefonlarından bir oda kodu üzerinden buluşup gerçek zamanlı oynar.

İki sürüm var:

| Sürüm | Klasör | Kimin için? |
|-------|--------|-------------|
| 🌐 **Web** (önerilen) | `docs/` | Sadece telefonu olanlar. Tarayıcıda linkle oynanır, kurulum/derleme yok. |
| 📱 **Flutter** (uygulama) | `lib/` | Bilgisayarı olup APK derleyebilenler. |

---

## 🌐 Web sürümü — sadece telefonla (bilgisayar gerekmez)

Tamamen tarayıcıda çalışır; GitHub Pages'te ücretsiz barınır. Yapman gerekenler:

### 1. Firebase projesi aç (telefon tarayıcısından)
1. **console.firebase.google.com** → yeni proje oluştur.
2. **Firestore Database → Create database** (test modunda başlat).
3. Proje Ayarları (dişli) → aşağı in → **Web uygulaması ekle** (`</>` simgesi).
   Sana `apiKey`, `projectId`... içeren bir "config" verecek.

### 2. Ayarları yapıştır (GitHub'da telefondan)
1. Bu depoda `docs/firebase-config.js` dosyasını aç → **kalem** (düzenle) simgesi.
2. `BURAYA_YAPISTIR` yazan yerleri Firebase'in verdiği değerlerle değiştir.
3. **Commit changes** ile kaydet.

### 3. GitHub Pages'i aç
1. Depoda **Settings → Pages**.
2. Source: **Deploy from a branch** → Branch: bu dal, klasör: **/docs** → Save.
3. 1-2 dakika sonra bir link çıkar (örn. `https://KULLANICI.github.io/uno_online/`).

### 4. Oyna
Linki aç, "Yeni Oyun Kur" de, çıkan kodu arkadaşına gönder; o da linki açıp
"Oyuna Katıl" ile kodu girsin. Herkes kendi telefonundan oynar. 🎉

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
