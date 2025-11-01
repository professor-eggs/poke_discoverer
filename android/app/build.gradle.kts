// Task to rename APK after build (works for AGP 7+ and Kotlin DSL)
tasks.register<Copy>("renameDebugApk") {
    val buildType = "debug"
    val versionName = android.defaultConfig.versionName
    val appName = "poke-discoverer"
    val apkDir = layout.buildDirectory.dir("outputs/apk/$buildType")
    val apkName = "app-$buildType.apk"
    val newName = "$appName-$versionName-$buildType.apk"

    from(apkDir)
    include(apkName)
    into(apkDir)
    rename(apkName, newName)
    dependsOn("assemble${buildType.replaceFirstChar { it.uppercase() }}")
}

tasks.register<Copy>("renameReleaseApk") {
    val buildType = "release"
    val versionName = android.defaultConfig.versionName
    val appName = "poke-discoverer"
    val apkDir = layout.buildDirectory.dir("outputs/apk/$buildType")
    val apkName = "app-$buildType.apk"
    val newName = "$appName-$versionName-$buildType.apk"

    from(apkDir)
    include(apkName)
    into(apkDir)
    rename(apkName, newName)
    dependsOn("assemble${buildType.replaceFirstChar { it.uppercase() }}")
}
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.professor_eggs.pokediscoverer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "your_keystore_password"
            keyAlias = System.getenv("KEY_ALIAS") ?: "release"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "your_key_password"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.github.professor_eggs.pokediscoverer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Use the release signing config for reproducible builds
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
