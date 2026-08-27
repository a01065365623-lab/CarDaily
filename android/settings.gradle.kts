pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.0" apply false
    // google_mobile_ads(play-services-ads)가 최신 Kotlin 메타데이터로 컴파일돼 있어
    // 1.8.22로는 "incompatible version of Kotlin" 컴파일 에러가 난다. LexTile에서
    // 검증된 버전으로 맞춘다.
    id("org.jetbrains.kotlin.android") version "2.1.21" apply false
}

include(":app")
