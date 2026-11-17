import 'package:flutter/material.dart';

class LifeVerseColors {
  static const canvas = Color(0xFF0D0E20);
  static const surface = Color(0xFF151630);
  static const raised = Color(0xFF1E2041);
  static const panel = Color(0xFF29264F);
  static const line = Color(0xFF34365B);
  static const primary = Color(0xFFB7A4FF);
  static const onPrimary = Color(0xFF171331);
  static const secondary = Color(0xFF8EDBD2);
  static const muted = Color(0xFFB6B7CF);
  static const success = Color(0xFF83D6AE);
  static const warning = Color(0xFFF0C982);
  static const danger = Color(0xFFF08D9B);
}

class LifeVerseTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: LifeVerseColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: LifeVerseColors.primary,
      secondary: LifeVerseColors.secondary,
      surface: LifeVerseColors.surface,
      error: LifeVerseColors.danger,
      onSurface: const Color(0xFFF5F2FF),
      onPrimary: LifeVerseColors.onPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: LifeVerseColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: LifeVerseColors.canvas,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Color(0xFFF5F2FF),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: LifeVerseColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: LifeVerseColors.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LifeVerseColors.raised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: LifeVerseColors.danger, width: 1.5),
        ),
        hintStyle: const TextStyle(color: LifeVerseColors.muted),
        labelStyle: const TextStyle(color: LifeVerseColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          side: const BorderSide(color: LifeVerseColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: LifeVerseColors.surface,
        indicatorColor: LifeVerseColors.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? LifeVerseColors.primary : LifeVerseColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: LifeVerseColors.surface,
        indicatorColor: LifeVerseColors.primary.withValues(alpha: .18),
        selectedIconTheme: const IconThemeData(color: LifeVerseColors.primary),
        unselectedIconTheme: const IconThemeData(color: LifeVerseColors.muted),
        selectedLabelTextStyle: const TextStyle(
          color: LifeVerseColors.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: LifeVerseColors.muted,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: LifeVerseColors.raised,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LifeVerseColors.primary,
        linearTrackColor: LifeVerseColors.line,
      ),
      dividerColor: LifeVerseColors.line,
      visualDensity: VisualDensity.standard,
    );
  }
}
