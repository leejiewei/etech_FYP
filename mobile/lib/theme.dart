import 'package:flutter/material.dart';

/// The same red and white identity as the website, so the app and the
/// shop obviously belong together.
class AppTheme {
  static const Color red = Color(0xFFD62839);
  static const Color redDark = Color(0xFF7A0C1F);
  static const Color redDarker = Color(0xFF5C0916);
  static const Color ink = Color(0xFF2F3640);
  static const Color line = Color(0xFFE3E6EA);
  static const Color pageBg = Color(0xFFF4F5F7);

  static const Color green = Color(0xFF1E8E3E);
  static const Color amber = Color(0xFF96690B);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: red,
          primary: red,
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: redDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: red, width: 1.6),
          ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: Colors.white,
          side: BorderSide(color: line),
        ),
      );

  /// Colours for the In Stock / Low Stock / Out of Stock pill.
  static Color stockColour(String stock) {
    switch (stock) {
      case 'in':
        return green;
      case 'low':
        return amber;
      default:
        return red;
    }
  }

  static Color stockBg(String stock) {
    switch (stock) {
      case 'in':
        return const Color(0xFFE3F8E8);
      case 'low':
        return const Color(0xFFFFF4DD);
      default:
        return const Color(0xFFFDE8E8);
    }
  }

  static Color statusColour(String status) {
    switch (status) {
      case 'Delivered':
        return green;
      case 'Shipped':
        return const Color(0xFF6A3FB5);
      case 'Processing':
        return const Color(0xFF2C5D8F);
      case 'Cancelled':
        return red;
      default:
        return amber;
    }
  }
}

String money(num amount) => 'RM ${amount.toStringAsFixed(2)}';
