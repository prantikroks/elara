// This file applies the plugins
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin") // This is essential for Flutter
}

// This applies the Sceneform plugin you defined in the other file
apply(plugin = "com.google.ar.sceneform.plugin")

android {

    // !!! IMPORTANT: Change this to your unique app ID
    namespace = "com.yourcompany.projectelara"

    // --- THIS IS THE FIX ---
    compileSdk = 36 // This was 34
    // --- END FIX ---

    defaultConfig {
        // !!! IMPORTANT: Change this to your unique app ID
        applicationId = "com.yourcompany.projectelara"

        minSdk = 24

        // --- THIS IS THE FIX ---
        targetSdk = 36 // This was 34
        // --- END FIX ---

        // Hardcoding version numbers to get past the error
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            // Configure your signing here for production
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // --- THIS IS THE FIX YOU ASKED FOR ---
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }
    // --- END OF FIX ---

    // This tells the app where to find your Flutter code
    flutter {
        source = "../.."
    }

    // These are your AR dependencies from your original file
    dependencies {
        implementation("com.google.ar:core:1.41.0")
        implementation("com.google.ar.sceneform.ux:sceneform-ux:1.17.1")
    }
}