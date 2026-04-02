// ============================================================
// lib/core/theme/app_theme.dart
// ============================================================
// Définit l'apparence visuelle (ThemeData) pour les modes sombre et clair.
//
// Les deux thèmes référencent AppColors pour la cohérence. Le thème
// est appliqué dans main.dart via les propriétés `theme` et `darkTheme`
// du MaterialApp. Le thème actif est contrôlé par ThemeProvider.
//
// Décisions clés :
//   - fontFamily : 'Segoe UI' pour un look moderne et épuré.
//   - primaryColor : AppColors.accentBlue (le bleu signature).
//   - AppBarTheme : élévation zéro, correspond à l'arrière-plan du scaffold.
// ============================================================

import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Contient les définitions statiques ThemeData pour les modes sombre et clair.
class AppTheme {
  // Empêche l'instanciation — utiliser comme AppTheme.darkTheme etc.
  AppTheme._();

  /// Thème sombre — le style visuel principal et par défaut de l'application.
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,   // Bleu marine profond
    primaryColor: AppColors.accentBlue,              // Bleu signature
    cardColor: AppColors.cardFill,                   // Surface de carte sombre
    dividerColor: AppColors.sidebarSeparator,        // Séparateurs bleus subtils
    colorScheme: const ColorScheme.dark(
      background: AppColors.background,
      primary: AppColors.accentBlue,
      secondary: AppColors.accentBlue,
      surface: AppColors.cardFill,
      onSurface: AppColors.textWhite,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textWhite),
      bodyMedium: TextStyle(color: AppColors.textGray),
      titleLarge: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: AppColors.textWhite),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0, // Plat — pas d'ombre
      iconTheme: IconThemeData(color: AppColors.textWhite),
      titleTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    fontFamily: 'Segoe UI',
  );

  /// Thème clair — style blanc alternatif et épuré.
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50
    primaryColor: AppColors.accentBlue,
    cardColor: const Color(0xFFFFFFFF),
    dividerColor: const Color(0xFFE2E8F0), // Slate 200
    colorScheme: const ColorScheme.light(
      background: Color(0xFFF8FAFC),
      primary: AppColors.accentBlue,
      secondary: AppColors.accentBlue,
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF0F172A), // Slate 900
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF0F172A)),
      bodyMedium: TextStyle(color: Color(0xFF64748B)), // Slate 500
      titleLarge: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFFFF),
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF0F172A)),
      titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
    ),
    fontFamily: 'Segoe UI',
  );
}
