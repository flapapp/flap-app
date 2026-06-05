import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Flap design system tokens — the dark, premium "pro-athlete" palette and
/// typography established in the Claude Design handoff (`Flap App.html`).
///
/// Source-of-truth maps directly onto the design's CSS custom properties in
/// `flap/app.css` (`:root { ... }`). Keep these in sync if the design changes.
class FlapColors {
  FlapColors._();

  // Backgrounds
  static const bg = Color(0xFF070A08); // --bg
  static const bg1 = Color(0xFF0B0F0C); // --bg-1
  static const surfaceSolid = Color(0xFF0E1310); // --surface-solid
  static const card = Color(0xFF10160F); // --card
  static const card2 = Color(0xFF141B14); // --card-2

  // Translucent surfaces (over [bg])
  static const surface = Color(0x0BFFFFFF); // rgba(255,255,255,.045)
  static const surface2 = Color(0x12FFFFFF); // rgba(255,255,255,.07)

  // Borders
  static const border = Color(0x17FFFFFF); // rgba(255,255,255,.09)
  static const borderStrong = Color(0x29FFFFFF); // rgba(255,255,255,.16)

  // Text
  static const text = Color(0xFFEAF1EC); // --text
  static const muted = Color(0xFF828F86); // --muted
  static const muted2 = Color(0xFF5E685F); // --muted-2

  // Accents
  static const green = Color(0xFF4CAF50); // --green
  static const greenBright = Color(0xFF66D16C); // --green-bright
  static const greenDeep = Color(0xFF2C7A31); // --green-deep
  static const amber = Color(0xFFE0A94C); // --amber
  static const blue = Color(0xFF5C97E0); // --blue
  static const red = Color(0xFFE06464); // --red
  static const gold = Color(0xFFE7C25A); // --gold

  /// Ink used on top of the bright-green primary surfaces (#06140A).
  static const onGreen = Color(0xFF06140A);

  /// Radial green glow behind the top of each screen (`.screen-bg`).
  static const RadialGradient screenGlow = RadialGradient(
    center: Alignment(0, -1.16), // 50% -8%
    radius: 1.1,
    colors: [Color(0x294CAF50), Color(0x00070A08)], // rgba(76,175,80,.16) -> transparent
    stops: [0.0, 0.46],
  );

  /// Primary CTA gradient (`.btn-primary`).
  static const LinearGradient primaryButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF62CC66), Color(0xFF42A046)],
  );
}

class FlapRadii {
  FlapRadii._();

  static const double card = 20;
  static const double tile = 16;
  static const double field = 14;
  static const double chip = 11;
  static const double iconButton = 13;
}

/// Typography helpers. Saira Condensed for athletic display caps, Sora for UI.
class FlapText {
  FlapText._();

  /// Athletic condensed display face (`.cond`, headlines, big numbers).
  static TextStyle cond({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color color = FlapColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.sairaCondensed(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Primary UI / body face (`Sora`).
  static TextStyle sora({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w500,
    Color color = FlapColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// Builds the app-wide [ThemeData] for the Flap dark-green design system.
ThemeData buildFlapTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: FlapColors.green,
      onPrimary: FlapColors.onGreen,
      secondary: FlapColors.greenBright,
      surface: FlapColors.card,
      onSurface: FlapColors.text,
      error: FlapColors.red,
    ),
    scaffoldBackgroundColor: FlapColors.bg,
  );

  return base.copyWith(
    textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
      bodyColor: FlapColors.text,
      displayColor: FlapColors.text,
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: FlapColors.text),
      foregroundColor: FlapColors.text,
    ),
  );
}
