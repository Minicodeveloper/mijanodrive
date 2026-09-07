import 'package:flutter/material.dart';

/// Identidad visual de Mijano Drive.
/// Amarillo exacto del logotipo (#FBD93A) + negro suave (#282828).
class MijanoTheme {
  static const Color sol = Color(0xFFFBD93A);
  static const Color solDeep = Color(0xFFE6C22A);
  static const Color ink = Color(0xFF282828);
  static const Color signal = Color(0xFFFF4D2E);
  static const Color cream = Color(0xFFFFFBE6);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sol,
        primary: sol,
        onPrimary: ink,
        secondary: ink,
      ),
      scaffoldBackgroundColor: Colors.white,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: sol,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: ink, fontSize: 20, fontWeight: FontWeight.w800),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: sol,
          disabledBackgroundColor: Colors.grey.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ink, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ink.withOpacity(0.25), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ink, width: 2.5),
        ),
      ),
    );
  }
}
