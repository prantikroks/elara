// Top-level build file
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This is required for your Sceneform/AR dependency to work
        classpath("com.google.ar.sceneform:plugin:1.17.1")
    }
}

plugins {
    // --- THIS IS THE FIX ---

    // 1. We add back the versions, as the new error requires.
    // 2. We use '8.11.1' because a previous error told us
    //    this is the version your system is using.
    id("com.android.application") version "8.11.1" apply false

    // 3. We use a Kotlin version that is compatible with this.
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false

    // 4. We REMOVE the 'dev.flutter.flutter-plugin-loader' line.
    //    A previous error showed it was already on the classpath
    //    with an 'unknown version', so defining it here was
    //    causing a conflict.

    // --- END OF FIX ---
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}