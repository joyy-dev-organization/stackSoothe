import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0B0F14);
  static const sidebar = Color(0xFF0D1219);
  static const surface = Color(0xFF121923);
  static const surfaceRaised = Color(0xFF171F2B);
  static const input = Color(0xFF0D141D);
  static const border = Color(0xFF263242);
  static const text = Color(0xFFEAF0F8);
  static const muted = Color(0xFF8C9AAF);
  static const subtle = Color(0xFF5F6F83);
  static const accent = Color(0xFF9A8CFF);
  static const accentDark = Color(0xFF6556D9);
  static const success = Color(0xFF61D9A6);
  static const warning = Color(0xFFFFC477);
  static const danger = Color(0xFFFF777F);
  static const cyan = Color(0xFF76D8E8);
}

class AppTheme {
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: AppColors.accent,
      secondary: AppColors.cyan,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      cardColor: AppColors.surface,
      splashFactory: InkSparkle.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x669A8CFF),
        selectionHandleColor: AppColors.accent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.input,
        hintStyle: const TextStyle(color: AppColors.subtle),
        labelStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: const Color(0xFF100D22),
          disabledBackgroundColor: AppColors.accentDark.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.text.withValues(alpha: 0.65),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceRaised,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.text, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
    );
  }
}
