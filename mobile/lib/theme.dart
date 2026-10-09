import 'package:flutter/material.dart';

/// eTech's colours on a native Material 3 app.
///
/// The website is set as a shop receipt; the app stays an Android app,
/// with Android's own controls, and takes only the shop's palette from
/// it: thermal-paper ground, PAID-stamp blue, and the pink of a till
/// roll's end stripe, kept for prices that have dropped. Prices are set
/// in Azeret Mono, the face the website prints them in, so the same
/// number looks the same on both.
///
/// The old names (red, redDark, redDarker) are kept so every screen
/// follows the new palette without being edited; they now hold blues.
class AppTheme {
  static const Color stamp = Color(0xFF2448A8);
  static const Color stampDeep = Color(0xFF1A3683);
  static const Color stampInk = Color(0xFF13286A);
  static const Color stampTint = Color(0xFFE7ECF8);
  static const Color roll = Color(0xFFC42F6E);
  static const Color danger = Color(0xFFB3261E);

  static const Color red = stamp;
  static const Color redDark = stampDeep;
  static const Color redDarker = stampInk;
  static const Color ink = Color(0xFF1C1C1E);
  static const Color line = Color(0xFFDCDCD4);
  static const Color pageBg = Color(0xFFF6F6F2);

  static const Color green = Color(0xFF1D6B3A);
  static const Color amber = Color(0xFF855600);

  static const String priceFont = 'AzeretMono';

  /// A price, in the receipt face with even-width figures.
  static TextStyle price(double size, {Color color = ink, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontFamily: priceFont,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.4,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: stamp,
      primary: stamp,
      onPrimary: Colors.white,
      secondary: stampDeep,
      tertiary: roll,
      error: danger,
      surface: Colors.white,
      onSurface: ink,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: stamp,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: stampTint,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? stamp : const Color(0xFF5C5C57),
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? stamp : const Color(0xFF5C5C57),
            )),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: stamp,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: stamp,
          foregroundColor: Colors.white,
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: stamp,
          side: const BorderSide(color: Color(0xFFC4C4BB)),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: stamp),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC4C4BB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC4C4BB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: stamp, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: stampTint,
        side: BorderSide(color: line),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: stamp,
        selectionColor: stampTint,
        selectionHandleColor: stamp,
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
        return const Color(0xFFE3F1E8);
      case 'low':
        return const Color(0xFFFBF0D9);
      default:
        return const Color(0xFFFBE6E4);
    }
  }

  static Color statusColour(String status) {
    switch (status) {
      case 'Collected':
        return green;
      case 'Ready':
        return const Color(0xFF6A3FB5);
      case 'Processing':
        return const Color(0xFF2C5D8F);
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
