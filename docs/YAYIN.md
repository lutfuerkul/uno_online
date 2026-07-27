# Play Store yayın adımları

Sıra önemli: alt adımlar üstteki adımlara bağlı. `[sen]` işaretli olanlar
kimlik doğrulama / hesap erişimi gerektirdiği için elle yapılmalı.

## 1. Play Console hesabı — [sen]
25 $ tek seferlik ödeme + kimlik doğrulama. Doğrulama günler sürebildiği için
en başta başlatılır; kod tarafını beklemez.

## 2. Paket adı, imzalama altyapısı, CI — kod tarafı ✅
Bu adım tamamlandı:
- `applicationId` = `com.lutfuerkul.uwinokeypisti` (Play'deki kalıcı kimlik,
  yayın sonrası **değiştirilemez**)
- `android/app/build.gradle.kts` release imzasını `android/key.properties`ten
  okur; dosya yoksa debug anahtarına düşer (yerel test çalışmaya devam eder)
- CI hem debug APK (telefona kurulum) hem imzalı release AAB (Play) üretir

> ⚠️ Paket adı değiştiği için yeni APK telefona **ikinci bir uygulama** olarak
> kurulur. İlk kurulumdan önce eski uygulamayı silin; kayıtlı isim/fotoğraf
> gibi yerel veriler eskisiyle birlikte gider.

## 3. İmzalama anahtarını üret — [sen]
Kendi makinende, bir kez:

```bash
keytool -genkey -v -keystore ~/uwin-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```

- `.jks` dosyasını **yedekle**. Kaybedersen uygulamayı bir daha güncelleyemezsin.
- Depoya koyma (`.gitignore` zaten engelliyor).
- Yerelden imzalı derleme almak istersen `android/key.properties.example`
  dosyasını `android/key.properties` olarak kopyalayıp doldur.

## 4. GitHub secret'ları — [sen]
Settings → Secrets and variables → Actions:

| Secret | Değer |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 ~/uwin-upload.jks` çıktısı |
| `ANDROID_KEYSTORE_PASSWORD` | keystore parolası |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | anahtar parolası |

Eklendikten sonra CI otomatik olarak `uwin-okey-pisti-release-aab`
artifact'ini de üretmeye başlar. Eklenmeden önce bu adım atlanır, CI yeşil
kalır ve APK üretilmeye devam eder.

## 5. Güvenlik: anonim auth + Firestore kuralları — kod tarafı ✅
Kod tarafı tamamlandı: uygulama açılışta Firebase'e anonim oturum açıyor,
oyuncu kimliği artık bu oturumun UID'si ve `firestore.rules` yetkiyi buna
dayandırıyor (odayı yalnızca odadaki oyuncular değiştirebiliyor, okuma
kimlik doğrulaması istiyor).

**Sıra önemli, yoksa uygulama kilitlenir:**

1. **Önce** Firebase Console → Authentication → Sign-in method →
   **Anonymous** sağlayıcısını aç.
2. Yeni istemciyi kur ve online oyunun çalıştığını doğrula (bu aşamada eski
   kurallar hâlâ yürürlükte, istemci her iki kural setiyle de çalışır).
3. **Sonra** kuralları deploy et:
   ```bash
   firebase deploy --only firestore:rules
   ```
   (Repoda `firebase.json` yok — Firebase Console → Firestore → Rules
   üzerinden elle de yapıştırılabilir.)
4. Oda kur / katıl / hamle yap / çık akışlarını tekrar doğrula.
5. (Oda temizliği) Firestore → TTL: `games`, `pisti_games`, `okey_games`
   koleksiyonlarında `expireAt` alanına TTL politikası ekle (ayrıntı
   aşağıda "Bilinen açık konular").

Anonim sağlayıcı açılmadan kurallar deploy edilirse istemci oturum açamaz ve
**tüm online işlemler permission-denied alır**. Eski istemci sürümleri de
(anonim oturum açmayanlar) yeni kurallar altında çalışmaz.

Kuralların davranışı emülatörle test edilebilir:
`test/firestore_rules/README.md`.

## 6. Firebase'de Android uygulamasını kaydet — [sen]
`lib/firebase_options.dart` içindeki Android `appId` şu an **web**
uygulamasının kimliği (`...:web:...`) ve `google-services.json` yok. Firestore
çalışıyor ama API anahtarı paket adı + SHA-1 ile kısıtlanamıyor.

```bash
flutterfire configure
```

## 7. Mağaza içeriği — [sen]
- **Gizlilik politikası URL'si (zorunlu)** — uygulama profil fotoğrafı ve isim
  topluyor
- Veri güvenliği (Data safety) formu: fotoğraf + isim, toplanıyor ve aktarılıyor
- İçerik derecelendirme anketi, hedef kitle beyanı
- Görseller: 512×512 ikon, 1024×500 öne çıkan görsel, telefon **ve tablet**
  ekran görüntüleri
- Metinlerde **"UNO" geçmesin** — Mattel'in tescilli markası

## 8. Kapalı test: 12 kişi × 14 gün — [sen]
Kasım 2023 sonrası açılan bireysel hesaplarda üretime geçmeden önce en az
12 test kullanıcısıyla 14 gün kesintisiz kapalı test zorunlu. En uzun süren
adım bu; ilk AAB hazır olur olmaz başlat. 6. ve 7. adımlar bu süre içinde
paralel yürütülebilir.

## 9. İlk yüklemeden sonra — [sen]
Play App Signing devrede olduğu için mağazadaki imza anahtarı Google'ın
ürettiği anahtardır. Play Console → App integrity ekranından **app signing
SHA-1**'i alıp Firebase'e ekle, ardından Google Cloud Console'dan API
anahtarını paket adı + SHA-1 ile kısıtla. Bu ancak ilk yüklemeden sonra
mümkün.

## 10. Üretime geçiş — [sen]

---

## Bilinen açık konular
- `firestore.rules` otomatik deploy edilmiyor; her değişiklikte elle deploy
  gerekiyor.
- **Oda TTL (elle kurulum):** Kod `expireAt` (Timestamp) yazıyor ve son
  oyuncu çıkınca odayı siliyor. Terk edilmiş odalar için Firebase Console →
  Firestore → Time-to-live (TTL) altında şu koleksiyonlara politika ekle
  (field: `expireAt`):
  - `games`
  - `pisti_games`
  - `okey_games`
  TTL politikası yoksa `expireAt` yalnızca alan olarak durur; silme olmaz.
  Eski (expireAt'siz) belgeler bir sonraki yazmada alan kazanır veya elle
  temizlenir. Süreler: waiting 24 saat, playing 2 gün (her hamlede yenilenir),
  finished 12 saat.
- iOS tarafı yapılandırılmadı (`iosBundleId` hâlâ `com.example.unoOnline`).
  Yalnızca Play hedefleniyorsa sorun değil.
