import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// Signing the release build.
//
// Until now `release` was signed with `signingConfigs.getByName("debug")`
// -- the line Flutter generates, with a TODO above it that never got
// done. That is not a weak key, it is a *published* one: the debug
// keystore ships with the Android SDK and is byte-identical on every
// machine in the world, password "android".
//
// What that means in practice is that anybody can take the APK handed to
// a beta tester, unpack it, change it -- point it at their own Supabase
// project, add code that reads what the tester types -- re-sign it with
// the same debug key, and Android will install it over the top as a
// legitimate update of this app. Signing is the only thing that ties an
// APK to whoever built it, and a key everyone has ties it to nobody.
//
// So the real key is read from android/key.properties, which is already
// in .gitignore along with *.jks and *.keystore, and must never be
// committed.
//
// TO CREATE ONE (once, then keep the .jks file safe -- losing it means
// no future build can ever update an installed copy):
//
//   keytool -genkey -v -keystore %USERPROFILE%\etech-release.jks //     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias etech
//
// then write mobile/android/key.properties:
//
//   storePassword=<what you typed>
//   keyPassword=<what you typed>
//   keyAlias=etech
//   storeFile=C:/Users/<you>/etech-release.jks
//
// Without that file a release build still works and still uses the debug
// key, because blocking `flutter build apk` outright would be worse than
// the problem -- but it prints the warning below every time, so it
// cannot be forgotten quietly the way the TODO was.
// ============================================================
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.etech.etech_mobile"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.etech.etech_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "eTech: no android/key.properties, so this release APK is signed " +
                    "with the PUBLIC Android debug key. Anyone can re-sign a modified " +
                    "copy as this app. Fine while testing on your own phone; create a " +
                    "real keystore before handing the APK to beta testers -- see the " +
                    "comment at the top of android/app/build.gradle.kts."
                )
                signingConfigs.getByName("debug")
            }

            // R8: shrinks and obfuscates the Java/Kotlin side and strips
            // unused resources. Flutter's own Dart code is already AOT
            // compiled into libapp.so and is not affected either way, so
            // this is a smaller download and a slightly harder APK to
            // read rather than a security control on its own.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
