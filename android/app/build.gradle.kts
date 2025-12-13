plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ...

    // Add the dependency for the Google services Gradle plugin
    // Version is provided on the classpath by the workspace/tooling; avoid redeclaring to prevent
    // "already on the classpath with a different version" errors.
    id("com.google.gms.google-services") apply false

}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.4.0"))


    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    // https://firebase.google.com/docs/android/setup#available-libraries
    // Core library desugaring (provides java.time and other newer JDK APIs on older
    // Android runtimes) required by some AARs (e.g. flutter_local_notifications).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

android {
    // Use the applicationId/package from your Firebase config (google-services.json)
    namespace = "com.ricardo.caja_ahorro_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        // Enable core library desugaring so libraries that require newer Java APIs
        // can be used on older Android devices.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Target JVM version for Kotlin. Keep this aligned with Java compile options.
        // Reverted to 11 to match the project's Java compile target and avoid
        // "Inconsistent JVM-target compatibility" build errors.
        jvmTarget = "21"
    }

    defaultConfig {
    // Ensure this matches the `client.client_info.android_client_info.package_name`
    // value in android/app/google-services.json
    applicationId = "com.ricardo.caja_ahorro_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// Apply the Google services plugin so google-services.json is processed and
// Firebase resources (values.xml) are generated for the app.
apply(plugin = "com.google.gms.google-services")
