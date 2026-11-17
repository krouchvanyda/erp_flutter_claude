import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}
dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.13.0"))


    // TODO: Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")


    // Add the dependencies for any other desired Firebase products
    // https://firebase.google.com/docs/android/setup#available-libraries

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
// Release signing for the `prod` flavor (Play Store). android/key.properties:
//   storePassword=…  keyPassword=…  keyAlias=…  storeFile=/abs/path/upload-keystore.jks
// Never commit key.properties or the keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.enterprise.erp.erp_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.enterprise.erp.erp_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    // Flavors: dev / uat / prod — `flutter run --flavor <name> -t lib/main_<name>.dart`.
    // All three keep the SAME applicationId (one Firebase / FCM registration in
    // google-services.json), so only one flavor can be installed at a time.
    // They differ by launcher name (here) and backend URL (lib/core/config/flavor.dart).
    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            resValue("string", "app_name", "ERP Dev")
        }
        create("uat") {
            dimension = "env"
            resValue("string", "app_name", "ERP UAT")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", "ERP")
            // Play Store builds are signed with the upload key; dev / uat
            // release builds use the debug key (fine for testers, not the store).
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    buildTypes {
        release {
            // dev / uat: debug key so `flutter run --release` works anywhere.
            // prod: the flavor's own signingConfig (above) wins over this.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Fail fast instead of shipping a debug-signed prod release.
gradle.taskGraph.whenReady {
    val buildsProdRelease = allTasks.any { it.name.contains("ProdRelease") }
    if (buildsProdRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "prod release builds need android/key.properties (upload keystore). " +
                "See the comment at the top of android/app/build.gradle.kts."
        )
    }
}

flutter {
    source = "../.."
}
