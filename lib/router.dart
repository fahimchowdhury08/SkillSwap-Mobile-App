import 'package:flutter/material.dart';

class AppColors {
  // Base backgrounds
  static const Color background  = Color(0xFF0D1B2A);
  static const Color cardSurface = Color(0xFF162032);
  static const Color elevated    = Color(0xFF1E2D45);

  // Primary accents
  static const Color indigo      = Color(0xFF5B4FE9);
  static const Color coral       = Color(0xFFFF6B6B);
  static const Color green       = Color(0xFF4CAF50);
  static const Color gold        = Color(0xFFFFD700);

  // Text
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCDD);
  static const Color textMuted     = Color(0xFF9999BB);

  // Skill chip colors
  static const Color chipPython    = Color(0xFFFF6B6B);
  static const Color chipFullStack = Color(0xFF8B5CF6);
  static const Color chipMarketing = Color(0xFF14B8A6);
  static const Color chipDesign    = Color(0xFFF59E0B);
  static const Color chipData      = Color(0xFF3B82F6);
  static const Color chipOther     = Color(0xFF6B7280);
}

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
    fontWeight: FontWeight.w700,
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

class AppSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm     = 8;
  static const double md     = 12;
  static const double lg     = 16;
  static const double xl     = 24;
  static const double pill   = 100;
}