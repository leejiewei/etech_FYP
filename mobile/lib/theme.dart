import 'package:flutter/material.dart';

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
  static const Color brand = Color(0xFFBC2000);
  static const Color brandDeep = Color(0xFF9A1A00);
  static const Color brandInk = Color(0xFF6E1300);
  static const Color brandTint = Color(0xFFFDEBE6);
  static const Color danger = Color(0xFFB3261E);

  static const Color red = brand;
  static const Color redDark = brandDeep;
  static const Color redDarker = brandInk;
  static const Color roll = brand; // a deal price
  static const Color ink = Color(0xFF16181D);
  static const Color ink3 = Color(0xFF5C636E);
  static const Color line = Color(0xFFE2E5E9);
  static const Color line2 = Color(0xFFC8CDD3);
  static const Color pageBg = Color(0xFFF3F4F6);

  static const Color green = Color(0xFF1D6B3A);
  static const Color amber = Color(0xFF855600);

  static const double radius = 4;

  /// A price: bold, with even-width figures so a column of them lines up.
  static TextStyle price(double size, {Color color = ink, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: -0.2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      primary: brand,
      onPrimary: Colors.white,
      secondary: brandDeep,
      tertiary: brand,
      error: danger,
      surface: Colors.white,
      onSurface: ink,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: line)),
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
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
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          shape: rounded,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: const BorderSide(color: line2),
          shape: rounded,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: brand),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: line2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: line2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: brand, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: brandTint,
        side: BorderSide(color: line),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
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
