# Firestore kuralları testi

`firestore.rules` dosyasını Firestore emülatörüne yükleyip yetkilendirmenin
gerçekten çalıştığını doğrular — özellikle **odada olmayan birinin o odaya
yazamadığını**.

Bu test Dart değil Node tabanlı (kural testi için resmi araç
`@firebase/rules-unit-testing`) ve **CI'da çalışmıyor**. `flutter test`'ten
bağımsızdır; yalnızca `firestore.rules` dosyasına dokunduğunda elle çalıştır.

## Çalıştırma

Java gerekiyor (emülatör JVM üzerinde çalışır).

```bash
cd test/firestore_rules
npm install firebase-tools firebase @firebase/rules-unit-testing

# 1. terminal — emülatörü başlat
npx firebase emulators:start --only firestore --project demo-test

# 2. terminal — testleri çalıştır
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node rules_test.mjs
```

Kuralları emülatöre test dosyası kendisi yüklüyor (`initializeTestEnvironment`
çağrısında depo kökündeki `firestore.rules` okunuyor), dolayısıyla emülatörü
başlatırken ayrı bir `firebase.json` gerekmiyor.

## Kapsam

Okuma yetkisi, oda kurma (kendi UID'siyle), odada olmayanın yazamaması,
bekleme odasına katılma, katılırken mevcut oyuncuyu çıkaramama, odadan
çıkma, **son kalan oyuncunun odayı silebilmesi** (çok oyunculu / yabancı
silme engeli) ve şema doğrulaması.
