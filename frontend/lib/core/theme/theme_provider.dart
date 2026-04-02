// ============================================================
// lib/core/theme/theme_provider.dart
// ============================================================
// Gère le mode de thème de l'application (clair ou sombre).
//
// Le thème sélectionné est PERSISTÉ avec SharedPreferences
// pour que le choix de l'utilisateur soit mémorisé entre les
// redémarrages de l'application.
//
// Par défaut : mode sombre si aucune préférence n'a été enregistrée.
//
// Exemple d'utilisation :
//   // Lire le mode actuel :
//   final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
//
//   // Basculer le thème :
//   Provider.of<ThemeProvider>(context, listen: false).toggleTheme(true);
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fournit et persiste le mode de thème de l'application (sombre ou clair).
class ThemeProvider extends ChangeNotifier {
  /// État interne — par défaut le mode sombre.
  ThemeMode _themeMode = ThemeMode.dark;

  /// Expose le ThemeMode actuel au MaterialApp.
  ThemeMode get themeMode => _themeMode;

  /// Getter pratique utilisé par les Paramètres pour lire l'état du bouton.
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    // Charge la préférence sauvegardée depuis le disque à la création du provider.
    _loadTheme();
  }

  /// Bascule entre le mode sombre et clair et sauvegarde le choix sur le disque.
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(isDark);
    notifyListeners(); // Reconstruit tous les widgets qui écoutent
  }

  /// Lit la préférence de thème sauvegardée depuis SharedPreferences.
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkMode') ?? true; // Défaut : sombre
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// Écrit la préférence de thème actuelle dans SharedPreferences.
  Future<void> _saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDark);
  }
}
