import 'package:flutter/material.dart';

import 'widgets/motion.dart';

/// eTech's look in the app: the same Shop Catalogue as the website
/// (design/TASTE.md, the :root block of web/css/style.css).
///
/// White cards with grey hairlines on a light grey ground, one red taken
/// from the round eTech logo, prices in bold with even-width figures,
/// buttons that say what they do. The red is the brand, the primary
/// action and a deal price, the way a shop marks its own sales.
///
/// The old names (red, redDark, redDarker, roll) are kept so every screen
/// follows the palette without being edited.
class AppTheme {
  /// Dark mode, set by the switch on the Account tab (or, until the
  /// customer uses it, the phone's own setting). Every colour below reads
  /// it, so the screens follow without being told. The dark values are
  /// the website's `:root[data-theme="dark"]` tokens in web/css/style.css.
  static bool dark = false;

  static Color _pick(int light, int night) => Color(dark ? night : light);

  static Color get brand => _pick(0xFFBC2000, 0xFFE04A2A);
  static Color get brandDeep => _pick(0xFF9A1A00, 0xFFC23A1D);
  static Color get brandInk => _pick(0xFF6E1300, 0xFFFFB4A3);
  static Color get brandTint => _pick(0xFFFDEBE6, 0xFF3A1A12);
  static Color get danger => _pick(0xFFB3261E, 0xFFFF7A6E);

  static Color get red => brand;
  static Color get redDark => brandDeep;
  static Color get redDarker => brandInk;
  static Color get roll => brand; // a deal price
  static Color get ink => _pick(0xFF16181D, 0xFFE6E8EB);
  static Color get ink3 => _pick(0xFF5C636E, 0xFF9AA1AB);
  static Color get line => _pick(0xFFE2E5E9, 0xFF2C3038);
  static Color get line2 => _pick(0xFFC8CDD3, 0xFF3D434D);
  static Color get pageBg => _pick(0xFFF3F4F6, 0xFF111317);
  static Color get card => _pick(0xFFFFFFFF, 0xFF1B1E24);
  static Color get surface2 => _pick(0xFFF7F7F9, 0xFF22262D);

  /// Near-black bands (the hero panels). Dark in both themes.
  static Color get night => _pick(0xFF16181D, 0xFF0A0B0E);

  static Color get green => _pick(0xFF1D6B3A, 0xFF5CC98A);
  static Color get amber => _pick(0xFF855600, 0xFFE5AD4F);
  static Color get okTint => _pick(0xFFE3F1E8, 0xFF15301F);
  static Color get warnTint => _pick(0xFFFBF0D9, 0xFF33280F);
  static Color get dangerTint => _pick(0xFFFBE6E4, 0xFF3A1815);
  static Color get info => _pick(0xFF2C5D8F, 0xFF7FB0E6);
  static Color get ready => _pick(0xFF6A3FB5, 0xFFB69CF0);

  static const double radius = 4;

  // Motion: the website's --dur-fast/base/slow and --ease-out. Taps are
  // fast, entrances are slow; nothing bounces. See widgets/motion.dart.
  static const Duration durFast = Duration(milliseconds: 150);
  static const Duration durBase = Duration(milliseconds: 200);
  static const Duration durSlow = Duration(milliseconds: 350);
  static const Curve easeOut = Cubic(0.2, 0.7, 0.2, 1);
  static const double rise = 12; // --space-3: how far a page or card rises in
  static const double pressScale = 0.98; // a pressed card or button, as on the web

  /// A pressed red button darkens to brandDeep, the website's hover and
  /// press colour, on top of the ripple.
  static WidgetStateProperty<Color?> get _pressedDeep =>
      WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.pressed) ? brandDeep : null);

  /// A price: bold, with even-width figures so a column of them lines up.
  static TextStyle price(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      secondary: brandDeep,
      tertiary: brand,
      error: danger,
      surface: card,
      onSurface: ink,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      // iOS keeps its own swipe-back slide.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: RisePageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: RisePageTransitionsBuilder(),
        TargetPlatform.linux: RisePageTransitionsBuilder(),
        TargetPlatform.fuchsia: RisePageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: line)),
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: brandTint,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? brand : ink3,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? brand : ink3,
            )),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: line),
        ),
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          animationDuration: durFast,
        ).copyWith(overlayColor: _pressedDeep),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          animationDuration: durFast,
        ).copyWith(overlayColor: _pressedDeep),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: BorderSide(color: line2),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: brand, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: brandTint,
        side: BorderSide(color: line),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: night,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: brandTint,
        selectionHandleColor: brand,
      ),
    );
  }

  /// Colours for the In Stock / Low Stock / Out of Stock pill.
  static Color stockColour(String stock) {
    switch (stock) {
      case 'in':
        return green;
      case 'low':
        return amber;
      default:
        return danger;
    }
  }

  static Color stockBg(String stock) {
    switch (stock) {
      case 'in':
        return okTint;
      case 'low':
        return warnTint;
      default:
        return dangerTint;
    }
  }

  static Color statusColour(String status) {
    switch (status) {
      case 'Collected':
        return green;
      case 'Ready':
        return ready;
      case 'Processing':
        return info;
      case 'Cancelled':
        return danger;
      default:
        return amber;
    }
  }
}

/// RM with grouped thousands: RM 2,899.00.
String money(num amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return 'RM $whole.${parts[1]}';
}
