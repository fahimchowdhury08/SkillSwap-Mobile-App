
import 'package:flutter/material.dart';

// ── App Colors ────────────────────────────────────────────────
// Use these everywhere instead of hardcoding hex values
// Example: color: AppColors.indigo

class AppColors {
  // ── Base Backgrounds ────────────────────────────────────────
  static const Color background  = Color(0xFF0D1B2A); // main screen background
  static const Color cardSurface = Color(0xFF162032); // cards, form fields
  static const Color elevated    = Color(0xFF1E2D45); // modals, drawers, popups

  // ── Primary Accents ─────────────────────────────────────────
  static const Color indigo      = Color(0xFF5B4FE9); // primary — buttons, tabs, active
  static const Color coral       = Color(0xFFFF6B6B); // action — swap button, CTAs

  // ── Status Colors ───────────────────────────────────────────
  static const Color green       = Color(0xFF4CAF50); // success, accepted, online
  static const Color gold        = Color(0xFFFFD700); // ratings, stars
  static const Color red         = Color(0xFFE53935); // error, reject, block
  static const Color orange      = Color(0xFFFF9800); // pending, warning

  // ── Text Colors ─────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF); // main text — white
  static const Color textSecondary = Color(0xFFCCCCDD); // body text — soft white
  static const Color textMuted     = Color(0xFF9999BB); // labels, hints, timestamps

  // ── Skill Chip Colors ────────────────────────────────────────
  // Each skill category has its own chip color
  static const Color chipPython    = Color(0xFFFF6B6B); // coral
  static const Color chipFullStack = Color(0xFF8B5CF6); // purple
  static const Color chipMarketing = Color(0xFF14B8A6); // teal
  static const Color chipDesign    = Color(0xFFF59E0B); // amber
  static const Color chipData      = Color(0xFF3B82F6); // blue
  static const Color chipOther     = Color(0xFF6B7280); // gray

  // ── Gradient Helpers ─────────────────────────────────────────
  // Used for avatar rings, level cards, hero overlays
  static const LinearGradient indigoCoralGradient = LinearGradient(
    colors: [indigo, coral],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeroGradient = LinearGradient(
    colors: [Colors.transparent, background],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ── App Text Styles ───────────────────────────────────────────
// Use these everywhere for consistent typography
// Example: style: AppTextStyles.heading1

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w700,
    fontSize: 28,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w700,
    fontSize: 22,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w700,
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w600,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w700,
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Nunito',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    color: AppColors.textMuted,
  );
}

// ── App Spacing ────────────────────────────────────────────────
// Consistent spacing values used for padding and margins
// Example: padding: EdgeInsets.all(AppSpacing.md)

class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

// ── App Theme ──────────────────────────────────────────────────
// The full ThemeData used in MaterialApp
// Used in app.dart as: theme: AppTheme.dark

class AppTheme {
  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.indigo,
    fontFamily: 'Nunito',

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardSurface,
      selectedItemColor: AppColors.indigo,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    // Input Fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardSurface,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontFamily: 'Nunito',
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.indigo, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        textStyle: AppTextStyles.button,
        minimumSize: const Size(double.infinity, 52),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.elevated,
      thickness: 1,
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    // Tab Bar
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.indigo,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.indigo,
      labelStyle: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),

    // Icon
    iconTheme: const IconThemeData(
      color: AppColors.textPrimary,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.elevated,
      contentTextStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}