import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system: all named colors, text styles, and the root ThemeData.
/// No screen should ever hardcode a hex color — use these constants.
class AppTheme {
  AppTheme._();

  // ── Background gradient ──────────────────────────────────────────
  static const Color gradientStart = Color(0xFF5B3A94);
  static const Color gradientEnd = Color(0xFF7854C4);

  // ── Grid panel ───────────────────────────────────────────────────
  static const Color gridPanel = Color(0xF0F5F0FF); // light lavender, semi-translucent
  static const Color gridPanelBorder = Color(0x33FFFFFF);

  // ── B-I-N-G-O header row colors ──────────────────────────────────
  static const Color bingoB = Color(0xFFE2574C); // coral red
  static const Color bingoI = Color(0xFFF0A63C); // amber/orange
  static const Color bingoN = Color(0xFF5CB85C); // green
  static const Color bingoG = Color(0xFF4A90D9); // blue
  static const Color bingoO = Color(0xFFA55FC7); // purple/magenta

  static const List<Color> bingoColors = [bingoB, bingoI, bingoN, bingoG, bingoO];
  static const List<String> bingoLetters = ['B', 'I', 'N', 'G', 'O'];

  // ── Cell states ──────────────────────────────────────────────────
  static const Color cellUnmarked = Color(0xFFE9E3F7);
  static const Color cellNumberText = Color(0xFF3A2A5C);
  static const Color cellMarked = Color(0xFFE2574C); // coral red
  static const Color cellMarkedText = Colors.white;
  static const Color freeSpaceStar = Color(0xFFFFD54F); // gold

  // ── Primary action ──────────────────────────────────────────────
  static const Color bingoButton = Color(0xFF5FC93F);
  static const Color bingoButtonText = Colors.white;

  // ── Stat badges ─────────────────────────────────────────────────
  static const Color badgeBackground = Color(0xCC1E1533); // dark charcoal/navy translucent
  static const Color badgeText = Colors.white;

  // ── Misc ────────────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFF5B3A94);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color cardSelectedBorder = Color(0xFF5FC93F);
  static const Color errorRed = Color(0xFFE2574C);
  static const Color successGreen = Color(0xFF5FC93F);
  static const Color dimOverlay = Color(0x99000000);

  // ── Dot texture ─────────────────────────────────────────────────
  static const Color dotColor = Color(0x15FFFFFF);

  // ── Text styles ─────────────────────────────────────────────────
  static TextStyle get _baseStyle => GoogleFonts.nunito();

  static TextStyle get headerStyle => _baseStyle.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: textPrimary,
      );

  static TextStyle get subheaderStyle => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      );

  static TextStyle get cellNumberStyle => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: cellNumberText,
      );

  static TextStyle get cellMarkedStyle => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: cellMarkedText,
      );

  static TextStyle get bingoHeaderLetterStyle => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      );

  static TextStyle get ballNumberStyle => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      );

  static TextStyle get badgeTextStyle => _baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: badgeText,
      );

  static TextStyle get buttonTextStyle => _baseStyle.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: bingoButtonText,
      );

  static TextStyle get countdownStyle => _baseStyle.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      );

  static TextStyle get emptyStateStyle => _baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      );

  static TextStyle get toastStyle => _baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  // ── ThemeData ───────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: scaffoldBg,
        colorScheme: ColorScheme.dark(
          primary: bingoButton,
          secondary: gradientEnd,
          surface: gridPanel,
          error: errorRed,
        ),
        textTheme: GoogleFonts.nunitoTextTheme(
          ThemeData.dark().textTheme,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: badgeBackground,
          contentTextStyle: toastStyle,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: bingoButton,
            foregroundColor: bingoButtonText,
            textStyle: buttonTextStyle,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
      );
}
