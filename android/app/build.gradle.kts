import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.norday.enfoque"
    // El de Flutter (36 en 3.44.4), como Norday Habits.
    // flutter_local_notifications 22.3.3 pide «at a minimum» 35 (su README,
    // «Gradle setup»).
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Desugaring: flutter_local_notifications lo exige «even if they
        // don't use scheduled notifications» (su README, «Gradle setup»).
        // https://developer.android.com/studio/write/java8-support#library-desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.norday.enfoque"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // También del README de flutter_local_notifications.
        multiDexEnabled = true
    }

    flavorDimensions += "entorno"
    productFlavors {
        // La de Play. Su applicationId no cambia nunca: com.norday.enfoque.
        create("produccion") {
            dimension = "entorno"
            manifestPlaceholders["appLabel"] = "Norday Focus"
        }
        // La de pruebas contra staging: otro applicationId, para tenerla
        // instalada a la vez que la de Play sin sustituirla.
        create("prueba") {
            dimension = "entorno"
            applicationIdSuffix = ".prueba"
            manifestPlaceholders["appLabel"] = "Focus PRUEBA"
        }
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // La versión que da el README de flutter_local_notifications 22.3.3.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-crashlytics")
}
