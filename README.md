# UNO Online

Çok oyunculu (şimdilik 2 kişilik) online UNO mobil oyunu. Flutter + Firebase
Firestore ile yapılmıştır. İki oyuncu kendi telefonlarından bir oda kodu
üzerinden buluşup gerçek zamanlı olarak oynar.

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
