import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Private constructor
  AppTheme._();

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.accentBlue,
    cardColor: AppColors.cardFill,
    dividerColor: AppColors.sidebarSeparator,
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
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textWhite),
      titleTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    fontFamily: 'Segoe UI',
  );

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
