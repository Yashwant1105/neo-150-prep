import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const ink = Color(0xFF070A09);
const surface = Color(0xFF0D1210);
const surface2 = Color(0xFF121A16);
const line = Color(0xFF223029);
const acid = Color(0xFFB7FF4A);
const muted = Color(0xFF8B9891);
const white = Color(0xFFF3F7F4);

ThemeData buildAppTheme() {
  final base = ThemeData.dark(
    useMaterial3: true,
  );

  final spaceGrotesk = GoogleFonts.spaceGroteskTextTheme(
    base.textTheme,
  ).apply(
    bodyColor: white,
    displayColor: white,
  );

  return base.copyWith(
    scaffoldBackgroundColor: ink,

    colorScheme: ColorScheme.fromSeed(
      seedColor: acid,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: acid,
      onPrimary: ink,
      secondary: acid,
    ),

    // =========================================================
    // TYPOGRAPHY
    // =========================================================
    //
    // Space Grotesk → headings / important UI
    // Manrope       → normal human-readable content
    // JetBrains Mono → technical data / numbers
    //

    textTheme: spaceGrotesk.copyWith(
      // -------------------------------------------------------
      // DISPLAY
      // -------------------------------------------------------

      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 57,
        fontWeight: FontWeight.w800,
        color: white,
        height: 1.05,
      ),

      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 45,
        fontWeight: FontWeight.w800,
        color: white,
        height: 1.05,
      ),

      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: white,
        height: 1.08,
      ),

      // -------------------------------------------------------
      // HEADLINES
      // -------------------------------------------------------

      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: white,
        height: 1.1,
      ),

      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: white,
        height: 1.12,
      ),

      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: white,
        height: 1.15,
      ),

      // -------------------------------------------------------
      // TITLES
      // -------------------------------------------------------

      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: white,
      ),

      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: white,
      ),

      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: white,
      ),

      // -------------------------------------------------------
      // BODY
      // -------------------------------------------------------

      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: white,
        height: 1.45,
      ),

      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: white,
        height: 1.4,
      ),

      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: muted,
        height: 1.4,
      ),

      // -------------------------------------------------------
      // LABELS
      // -------------------------------------------------------

      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: white,
      ),

      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: white,
      ),

      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: muted,
        letterSpacing: 0.6,
      ),
    ),

    // =========================================================
    // CARDS
    // =========================================================

    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),

    dividerColor: line,

    // =========================================================
    // INPUTS
    // =========================================================

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: line,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: line,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: acid,
          width: 1.2,
        ),
      ),
    ),
  );
}

// =============================================================================
// TECHNICAL FONT
// =============================================================================
//
// Used for:
// - XP
// - Levels
// - Problem numbers
// - Progress percentages
// - Streak numbers
// - Technical statistics
//

TextStyle technicalTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

// =============================================================================
// HUMAN FONT
// =============================================================================
//
// Used for:
// - Supporting text
// - Motivational text
// - Achievement descriptions
// - Empty states
//

TextStyle humanTextStyle({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.manrope(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}
