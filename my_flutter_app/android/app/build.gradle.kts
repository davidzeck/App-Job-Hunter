import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") apply false
}

// Firebase (push) reads android/app/google-services.json, downloaded from the Firebase
// console for the app ID below. Applied only when present, so builds work before then.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// ⚠️ PERMANENT once uploaded to Google Play — and Firebase registers the app by it.
// Replace with your domain reversed (e.g. ke.co.yourdomain.jobscout) BEFORE setting up
// Firebase and BEFORE the first Play upload: Job-backend/deploy/README.md §1.7.
val appId = "com.changeme.jobscout"

// Release signing with the upload key in android/key.properties (gitignored; §5 of the
// runbook). Without it, release builds use the debug key so `flutter run --release` works.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.example.my_flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = appId
        minSdk = flutter.minSdkVersion
        // Google Play requires new apps to target API 36 (Android 16) from 31 Aug
        // 2026; Flutter 3.38's default is 36 — check it when changing Flutter.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!keystoreProperties.isEmpty) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// A release build carrying the placeholder ID could be uploaded — and could never be
// changed afterwards. ALLOW_PLACEHOLDER_APP_ID=1 permits one for local testing only.
gradle.taskGraph.whenReady {
    val releasing = allTasks.any {
        it.name.endsWith("Release") && (it.name.startsWith("bundle") || it.name.startsWith("assemble"))
    }
    if (releasing && appId.startsWith("com.changeme") && System.getenv("ALLOW_PLACEHOLDER_APP_ID") != "1") {
        throw GradleException(
            "Set your real applicationId in android/app/build.gradle.kts before a release " +
                "build — it is permanent once uploaded to Google Play (deploy/README.md §1.7)."
        )
    }
}
