import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'api.dart';

/// Notifications that arrive with the app shut.
///
/// The bell inside the app is a Realtime subscription — a websocket held
/// open by a running process. Close the app and it closes with it, so the
/// customer who wanted to be told *without* opening the app was exactly
/// the one who could not be. Android will not let an app wake itself, so
/// reaching a closed one means Firebase Cloud Messaging.
///
/// ------------------------------------------------------------
/// This whole class is optional, on purpose.
///
/// Until somebody runs `flutterfire configure`, [DefaultFirebaseOptions]
/// is unset, [ready] is false, and every method here returns without
/// doing anything. The app builds, runs, signs in and sells exactly as it
/// did before — it simply has no push. That is deliberate: a shop app
/// that will not start because a Firebase project has not been made yet
/// is a worse outcome than one that does not buzz.
///
/// See docs/PUSH_SETUP.md for the two files that turn it on.
/// ------------------------------------------------------------
///
/// The push is a *copy* of the notification row, never the record itself.
/// The row is written by the database inside the same transaction as the
/// staff action that caused it, and the bell reads it whatever happens
/// here. So a push that never arrives — a dead token, a flat battery, a
/// customer who denied the permission — costs a buzz and nothing more.
class Push {
  static bool _started = false;
  static String? _token;

  /// Whether Firebase has been configured for this build at all.
  static bool get ready => DefaultFirebaseOptions.isConfigured;

  /// Called once at startup, before the first frame.
  ///
  /// Failures are swallowed and logged rather than thrown. Every one of
  /// them — no Firebase project, no Play Services on the handset, a
  /// network that is not there yet — describes a phone that cannot
  /// receive push, and none of them describes a phone that should be
  /// unable to shop.
  static Future<void> init() async {
    if (_started || !ready) return;
    _started = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Android 13 and up will not show a notification until the
      // customer has agreed. Asked here, at startup, rather than at the
      // moment the first message arrives — by then it is too late, the
      // message is already dropped.
      await FirebaseMessaging.instance.requestPermission();

      // A token identifies this *installation*, not this person. It is
      // registered against whoever is signed in at the time, and moves to
      // the next person who signs in on the same handset — see
      // register_device_token() in the migration, which conflicts on the
      // token and reassigns it.
      _token = await FirebaseMessaging.instance.getToken();
      await _register();

      // Tokens rotate on their own schedule: a restored backup, a cleared
      // cache, Google deciding it is time. Without this the phone goes
      // quiet and nothing anywhere reports a problem.
      FirebaseMessaging.instance.onTokenRefresh.listen((fresh) {
        _token = fresh;
        _register();
      });
    } catch (error) {
      debugPrint('Push unavailable: $error');
    }
  }

  /// Tell the shop which phone this is.
  ///
  /// Safe to call when signed out — it simply fails the session check on
  /// the other side and is swallowed. [Shop] calls it again after a
  /// successful sign-in, which is the call that usually does the work.
  static Future<void> _register() async {
    final token = _token;
    if (token == null) return;

    try {
      await Api.db.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': 'android',
      });
    } catch (error) {
      // Signed out is the ordinary case here, not a fault worth shouting
      // about.
      debugPrint('Could not register for push: $error');
    }
  }

  /// Re-register after signing in, so the handset is attached to the
  /// person now using it.
  static Future<void> onSignedIn() async {
    if (!ready) return;
    await _register();
  }

  /// Stop this handset receiving the previous customer's news.
  ///
  /// Called *before* the session is torn down, because by the time
  /// sign-out has finished there is no session left to authorise the
  /// call. The token itself is kept in memory: the same handset will
  /// re-register the moment somebody signs in again.
  static Future<void> onSignedOut() async {
    final token = _token;
    if (!ready || token == null) return;

    try {
      await Api.db.rpc('forget_device_token', params: {'p_token': token});
    } catch (error) {
      debugPrint('Could not unregister push: $error');
    }
  }
}
