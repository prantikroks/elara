// --- IMPORTS (to fix "Unresolved reference" errors) ---
import java.util.Properties
import java.io.File
import org.gradle.api.GradleException

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

// --- This block finds your Flutter SDK ---
val localProperties = Properties()
val localPropertiesFile = File(rootProject.projectDir, "local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(localPropertiesFile.inputStream())
}

val flutterSdkPath = localProperties.getProperty("flutter.sdk")
if (flutterSdkPath == null) {
    throw GradleException("flutter.sdk not found in local.properties. Create this file and add a line like 'flutter.sdk=C:\\path\\to\\your\\flutter\\sdk'")
}

// --- THIS IS THE FIX ---
// This replaces the old, deprecated 'app_plugin_loader.gradle'
// with the new, correct 'settings.gradle' file.
apply(from = File(flutterSdkPath, "packages/flutter_tools/gradle/settings.gradle"))
// --- END OF FIX ---

rootProject.name = "android"
include(":app")