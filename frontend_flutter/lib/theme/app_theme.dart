import 'package:flutter/material.dart';

// ── Design tokens (Todoist-inspired) ─────────────────────────────────────────

class C {
  // Brand
  static const primary = Color(0xFFE44232);
  static const primaryHover = Color(0xFFCF3520);
  static const primaryLight = Color(0xFFFFF6F0);
  static const primaryMid = Color(0xFFFFEFE5);

  // Backgrounds
  static const background = Color(0xFFFEFDFC);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF9F7F6);
  static const surfaceHover = Color(0xFFF2EFED);

  // Borders
  static const border = Color(0x2E25221E);
  static const borderLight = Color(0x1F25221E);

  // Text
  static const textPrimary = Color(0xFF25221E);
  static const textSecondary = Color(0xA825221E);
  static const textTertiary = Color(0x7D25221E);
  static const textPlaceholder = Color(0xFF97938C);
  static const textOnPrimary = Colors.white;

  // Semantic
  static const destructive = Color(0xFFE34432);
  static const destructiveLight = Color(0xFFFFF6F0);

  // Radius
  static const double radiusSm = 6;
  static const double radiusBase = 8;
  static const double radiusLg = 10;
  static const double radiusXl = 13;
  static const double radius2xl = 15;
  static const double radiusFull = 999;

  // Priority colors
  static const priorityUrgente = Color(0xFFEF4444);
  static const priorityHaute = Color(0xFFF97316);
  static const blue = Color(0xFF3B82F6);
  static const blueLight = Color(0xFFEFF6FF);
  static const green = Color(0xFF22C55E);
  static const purple = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF97316);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: C.background,
    colorScheme: ColorScheme.light(
      primary: C.primary,
      onPrimary: C.textOnPrimary,
      primaryContainer: C.primaryLight,
      secondary: C.textSecondary,
      surface: C.surface,
      onSurface: C.textPrimary,
      error: C.destructive,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.surface,
      foregroundColor: C.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: C.surface,
      selectedItemColor: C.primary,
      unselectedItemColor: C.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surfaceAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(C.radiusBase),
        borderSide: const BorderSide(color: C.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(C.radiusBase),
        borderSide: const BorderSide(color: C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(C.radiusBase),
        borderSide: const BorderSide(color: C.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: C.textPlaceholder, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: C.primary,
        foregroundColor: C.textOnPrimary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radiusBase)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.primary),
    ),
    dividerTheme: const DividerThemeData(color: C.borderLight, space: 0),
    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(C.radiusLg)),
    ),
  );
}
