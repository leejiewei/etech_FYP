import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Where this app's Firebase project is.
///
/// Filled in by hand from android/app/google-services.json rather than by
/// `flutterfire configure`. The CLI route wants firebase-tools, the
/// flutterfire CLI and an interactive browser login to produce these same
/// four strings, and it also rewrites this file in a shape that drops the
/// [isConfigured] getter that services/push.dart depends on. Copying the
/// four values across is fewer moving parts and one less thing to
/// remember the next time somebody regenerates it.
///
/// If the Firebase project is ever recreated, the values below come from
/// google-services.json like this:
///
///     projectId          project_info.project_id
///     messagingSenderId  project_info.project_number
///     appId              client[0].client_info.mobilesdk_app_id
///     apiKey             client[0].api_key[0].current_key
///
/// ------------------------------------------------------------
/// None of this is secret.
///
/// A Firebase appId and apiKey ship inside every Android app on the Play
/// Store and are readable by anyone who unzips an APK. They identify the
/// project; they do not authorise anything. Sending a notification needs
/// the service account key, which lives in a Supabase Edge Function
/// secret and never comes near this repository. Same reasoning that lets
/// the Supabase publishable key sit in config.dart.
/// ------------------------------------------------------------
class DefaultFirebaseOptions {
  /// Whether real values have been filled in. services/push.dart checks
  /// this before it touches Firebase at all, so an unconfigured build
  /// still runs -- it simply has no push.
  static bool get isConfigured => android.appId.isNotEmpty;

  static FirebaseOptions get currentPlatform => android;

  // Android only. The shop has no iOS build and no Apple developer
  // account, so there is deliberately no ios entry here to go stale.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCianHqvEMMnTekLsA8UI7ulb28qH0760',
    appId: '1:851500871224:android:77764c04490ab0c7e6c0cd',
    messagingSenderId: '851500871224',
    projectId: 'etech-fyp',
  );
}
