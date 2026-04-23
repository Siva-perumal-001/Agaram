import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgaramColors {
  static const primary = Color(0xFF690008);
  static const primaryContainer = Color(0xFF8B1A1A);
  static const onPrimary = Color(0xFFFFFFFF);

  static const secondary = Color(0xFF795900);
  static const secondaryContainer = Color(0xFFFFC641);
  static const onSecondary = Color(0xFFFFFFFF);

  static const surface = Color(0xFFFFF8F7);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFFFF0EF);
  static const surfaceContainer = Color(0xFFFFE9E6);
  static const surfaceContainerHigh = Color(0xFFFBE3E0);

  static const onSurface = Color(0xFF251817);
  static const onSurfaceVariant = Color(0xFF58413F);
  static const outline = Color(0xFF8C716E);
  static const outlineVariant = Color(0xFFE0BFBC);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);

  // Semantic status tones — reused across status chips, banners, success/error overlays.
  static const success = Color(0xFF2E7D32);
  static const successDark = Color(0xFF1B5E20);
  static const successContainer = Color(0xFFDDF2E3);
  static const warning = Color(0xFF795900);
  static const warningContainer = Color(0xFFFEF3D0);
  static const errorContainer = Color(0xFFFCE4E1);
  static const neutralContainer = Color(0xFFEFE7E6);
  static const info = Color(0xFF6C4BB6);
  static const infoSoft = Color(0xFF86BCE7);
  static const accentPeach = Color(0xFFFFB3AC);

  // Medal tones for leaderboard podium.
  static const silver = Color(0xFFB0B0B0);
  static const silverContainer = Color(0xFFEAEAEA);
  static const bronze = Color(0xFFCD7F32);
  static const bronzeContainer = Color(0xFFF3D6BC);

  // Scanner / dark overlay backdrop.
  static const scannerBackdrop = Color(0xFF151010);
}

class AgaramTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.02 * 32,
        color: AgaramColors.onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 36 / 28,
        color: AgaramColors.onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 28 / 22,
        color: AgaramColors.onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AgaramColors.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AgaramColors.onSurface,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.1,
        color: AgaramColors.onSurface,
      ),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AgaramColors.primary,
        onPrimary: AgaramColors.onPrimary,
        primaryContainer: AgaramColors.primaryContainer,
        secondary: AgaramColors.secondary,
        onSecondary: AgaramColors.onSecondary,
        secondaryContainer: AgaramColors.secondaryContainer,
        surface: AgaramColors.surface,
        onSurface: AgaramColors.onSurface,
        surfaceContainerLowest: AgaramColors.surfaceContainerLowest,
        surfaceContainerLow: AgaramColors.surfaceContainerLow,
        surfaceContainer: AgaramColors.surfaceContainer,
        surfaceContainerHigh: AgaramColors.surfaceContainerHigh,
        outline: AgaramColors.outline,
        outlineVariant: AgaramColors.outlineVariant,
        error: AgaramColors.error,
        onError: AgaramColors.onError,
      ),
      scaffoldBackgroundColor: AgaramColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AgaramColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AgaramColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AgaramColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AgaramColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AgaramColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AgaramColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(color: AgaramColors.onSurfaceVariant),
        labelStyle: GoogleFonts.inter(
          color: AgaramColors.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AgaramColors.primary,
          foregroundColor: AgaramColors.onPrimary,
          disabledBackgroundColor: AgaramColors.primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AgaramColors.primary,
          side: const BorderSide(color: AgaramColors.primary, width: 1.2),
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AgaramColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AgaramColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        margin: EdgeInsets.zero,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AgaramColors.onSurface,
        contentTextStyle: GoogleFonts.inter(color: AgaramColors.surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static TextStyle tamilSerif({
    double fontSize = 48,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.notoSerifTamil(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AgaramColors.primary,
    );
  }
}
