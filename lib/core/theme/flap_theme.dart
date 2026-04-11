import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic design tokens and [ThemeData] for FLAP — dark-first, pitch + accent.
abstract final class FlapTheme {
  static const Color pitch = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF121A22);
  static const Color surfaceElevated = Color(0xFF1A2430);
  static const Color outlineMuted = Color(0xFF2A3544);
  static const Color accent = Color(0xFF2EE6A6);
  static const Color accentDim = Color(0xFF1AA876);
  static const Color accentSecondary = Color(0xFF5B8DEF);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color onDark = Color(0xFFF2F5F8);
  static const Color onDarkMuted = Color(0xFF9AA8B8);

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static ThemeData theme() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        onPrimary: pitch,
        surface: surface,
        onSurface: onDark,
        secondary: accentSecondary,
        error: danger,
        outline: outlineMuted,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: pitch,
      canvasColor: pitch,
    );
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: onDark,
      displayColor: onDark,
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: onDark,
        iconTheme: const IconThemeData(color: onDark, size: 22),
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: surface.withValues(alpha: 0.94),
        indicatorColor: accent.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? accent : onDarkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? accent : onDarkMuted,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: outlineMuted, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: pitch,
          backgroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 4),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onDark,
          side: const BorderSide(color: outlineMuted),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm + 4),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: const BorderSide(color: outlineMuted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: const BorderSide(color: outlineMuted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: onDarkMuted),
        hintStyle: TextStyle(color: onDarkMuted.withValues(alpha: 0.8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: onDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm + 2),
        ),
      ),
      dividerTheme: const DividerThemeData(color: outlineMuted, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
    );
  }
}
