import 'package:flutter/material.dart';

import '../services/settings.dart';

/// The two header buttons the website has (web/js/layout.js): light or
/// dark, and music on or off. Sit in the app bar of every main tab, so
/// neither is more than one tap away. The same switches are also on the
/// Account tab; all of them change the one setting in AppSettings.
///
/// No listener of its own: a change rebuilds the whole app (see
/// _settingsChanged in main.dart), and these icons with it.
class SettingsButtons extends StatelessWidget {
  const SettingsButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: s.dark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(s.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          onPressed: () => s.setDark(!s.dark),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: s.musicOn ? 'Mute music' : 'Play music',
          icon: Icon(s.musicOn ? Icons.music_note_outlined : Icons.music_off_outlined),
          onPressed: () => s.setMusic(!s.musicOn),
        ),
      ],
    );
  }
}
