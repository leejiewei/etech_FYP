import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

/// The customer's own settings on this phone: light or dark mode, and
/// whether the background music plays. Both are switched on the Account
/// tab and kept in shared_preferences, so they survive the app closing.
///
/// Dark mode follows the phone's own setting until the customer picks
/// one, the same way the website does (web/js/theme.js).
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _themeKey = 'theme'; // 'light' | 'dark' | absent = follow the phone
  static const _musicKey = 'music'; // false = the customer turned it off

  SharedPreferences? _prefs;
  String? _theme;
  bool _musicOn = true;

  bool get musicOn => _musicOn;

  /// Dark when the customer chose dark, or chose nothing and the phone is dark.
  bool get dark {
    if (_theme != null) return _theme == 'dark';
    return SchedulerBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _theme = _prefs!.getString(_themeKey);
    _musicOn = _prefs!.getBool(_musicKey) ?? true;
    AppTheme.dark = dark;
  }

  void setDark(bool value) {
    _theme = value ? 'dark' : 'light';
    _prefs?.setString(_themeKey, _theme!);
    AppTheme.dark = value;
    notifyListeners();
  }

  /// The phone switched between light and dark while the app was open.
  void platformBrightnessChanged() {
    if (_theme != null) return;
    AppTheme.dark = dark;
    notifyListeners();
  }

  void setMusic(bool value) {
    _musicOn = value;
    _prefs?.setBool(_musicKey, value);
    value ? BackgroundMusic.play() : BackgroundMusic.pause();
    notifyListeners();
  }
}

/// One looping track, played quietly while the app is on screen.
///
/// TO CHANGE THE SONG: replace assets/audio/bgm.mp3 (keep the name) and
/// rebuild the app. It stops when the app goes to the background, so it
/// never plays from a pocket, and carries on when the app comes back.
class BackgroundMusic {
  static const _asset = 'audio/bgm.mp3'; // under assets/
  static const _volume = 0.25;

  static final AudioPlayer _player = AudioPlayer();
  static bool _started = false;
  static bool _missing = false;

  static Future<void> play() async {
    if (_missing || !AppSettings.instance.musicOn) return;
    try {
      if (!_started) {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.setVolume(_volume);
        await _player.play(AssetSource(_asset));
        _started = true;
      } else {
        await _player.resume();
      }
    } catch (e) {
      // No song in assets/audio yet: the app carries on in silence.
      _missing = true;
      debugPrint('Background music unavailable: $e');
    }
  }

  static Future<void> pause() async {
    if (_started) await _player.pause();
  }
}
