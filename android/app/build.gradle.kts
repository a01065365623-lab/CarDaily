import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 릴리즈 서명 정보는 android/key.properties(git 추적 제외)에서 읽어온다.
// 이 파일과 실제 keystore(.jks)는 android/.gitignore에 의해 항상 커밋에서 제외된다.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kbraingames.cardaily"
    // sound_mode_advanced(무음/진동 모드 감지)가 compileSdk 36을 요구해서
    // flutter.compileSdkVersion(35)보다 올려야 한다.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kbraingames.cardaily"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Google Play가 프로덕션 업로드에 minSdk 24 이상을 요구한다(google_mobile_ads는 23 요구).
        // Android 7.0(API 24) 미만 기기는 지원하지 않게 됨.
        minSdk = 24
        // Google Play 정책(2026-08-31~)에 따라 targetSdk 36(Android 16)을 명시적으로 고정.
        // flutter.targetSdkVersion은 현재 설치된 Flutter(3.29.3) 기준 35라서 직접 지정한다.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
