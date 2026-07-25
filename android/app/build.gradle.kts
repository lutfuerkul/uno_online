import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imzası için anahtar bilgileri `android/key.properties`ten okunur.
// Bu dosya repoya GİRMEZ (bkz. .gitignore) — geliştiricinin kendi makinesinde,
// CI'da ise secret'lardan üretilerek bulunur. Örnek için:
// `android/key.properties.example`.
//
// Dosya yoksa release derlemesi debug anahtarıyla imzalanır; böylece anahtarı
// olmayan biri de `flutter run --release` / `flutter build apk` çalıştırabilir.
// Bu şekilde imzalanan bir çıktı Play'e YÜKLENEMEZ, yalnızca yerel test
// içindir.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.lutfuerkul.uwinokeypisti"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Uygulamanın Play'deki kalıcı kimliği — yayınlandıktan sonra
        // DEĞİŞTİRİLEMEZ.
        applicationId = "com.lutfuerkul.uwinokeypisti"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
