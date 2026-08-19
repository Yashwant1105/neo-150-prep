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
    // GLOBAL FONT
    // =========================================================

    textTheme: spaceGrotesk,

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
