import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.mijano_drive_app"
    compileSdk = runCatching { flutter.compileSdkVersion }.getOrNull() ?: 35
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "net.mijano_drive_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = runCatching { flutter.minSdkVersion }.getOrNull() ?: 21
        targetSdk = runCatching { flutter.targetSdkVersion }.getOrNull() ?: 34
        versionCode = runCatching { flutter.versionCode }.getOrNull() ?: 1
        versionName = runCatching { flutter.versionName }.getOrNull() ?: "1.0"
    }

    signingConfigs {
        val hasKeyProperties = keystorePropertiesFile.exists() &&
            !keystoreProperties.getProperty("keyAlias").isNullOrBlank() &&
            !keystoreProperties.getProperty("keyPassword").isNullOrBlank() &&
            !keystoreProperties.getProperty("storeFile").isNullOrBlank() &&
            !keystoreProperties.getProperty("storePassword").isNullOrBlank()

        if (hasKeyProperties) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile") ?: "")
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
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
