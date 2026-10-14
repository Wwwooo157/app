plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dsh.beadlightboard"
    compileSdk = flutter.compileSdkVersion
    // Removed by project setup: ndkVersion = flutter.ndkVersion
    // Reason: this app is pure Dart plus Java/Kotlin plugins, it compiles no native
    // code. Keeping the line makes AGP auto-download a ~2-3 GB NDK for nothing.
    // Revisit only if a plugin with C/C++ sources is added later.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.dsh.beadlightboard"
        // Personal use only: no store publishing, so the release build intentionally
        // keeps the debug signing config below.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Personal use only, no publishing: sign release with the debug keys so
            // `flutter build apk --release` works without a keystore.
            signingConfig = signingConfigs.getByName("debug")
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
