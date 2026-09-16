import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Where this app's Firebase project is.
///
/// ------------------------------------------------------------
/// THIS FILE IS A PLACEHOLDER AND IS MEANT TO BE OVERWRITTEN.
///
/// Normally `flutterfire configure` generates it. Nothing here was
/// generated: there is no Firebase project yet, so the values below are
/// empty and [isConfigured] is false. Everything in services/push.dart
/// checks that flag first and does nothing when it is false, so the app
/// builds and runs perfectly well in this state — it simply has no push
/// notifications.
///
/// To turn push on, from the `mobile/` directory:
///
///     dart pub global activate flutterfire_cli
///     flutterfire configure --project=<your-firebase-project-id>
///
/// That overwrites this file wholesale with the real values, and
/// [isConfigured] becomes true because `appId` stops being empty. Nothing
/// else in the app needs editing — but do keep this doc comment's warning
/// in mind: the generated file has no `isConfigured`, so add it back, or
/// push.dart will not compile. docs/PUSH_SETUP.md says the same thing at
/// greater length.
///
/// These values are not secrets. A Firebase appId and apiKey ship inside
/// every Android app on the store and are useless without the app's
/// signing certificate, which is the same reasoning that lets the
/// Supabase publishable key sit in config.dart.
/// ------------------------------------------------------------
class DefaultFirebaseOptions {
  /// Whether real values have been filled in. Read by services/push.dart
  /// before it touches Firebase at all.
  static bool get isConfigured => _android.appId.isNotEmpty;

  static FirebaseOptions get currentPlatform => _android;

  // Android only. The shop has no iOS build and no Apple developer
  // account, so there is deliberately no ios entry to go stale.
  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: '',
    appId: '',
    messagingSenderId: '',
    projectId: '',
  );
}
