// ============================================================
// lib/core/l10n/locale_provider.dart
// ============================================================
// Gère la langue (locale) actuellement active de l'application.
//
// Quand l'utilisateur change de langue dans les Paramètres, ce provider
// met à jour la locale et notifie le MaterialApp pour reconstruire
// tous les textes avec les nouvelles traductions.
//
// Langues supportées (définies dans la classe `L10n`) :
//   'en' → English
//   'fr' → Français
//   'ar' → العربية
//
// Les traductions se trouvent dans les fichiers ARB sous lib/l10n/ :
//   app_en.arb, app_fr.arb, app_ar.arb
//
// Exemple d'utilisation :
//   Provider.of<LocaleProvider>(context, listen: false)
//     .setLocale(const Locale('fr'));
// ============================================================

import 'package:flutter/material.dart';

/// Fournit et gère la langue active de l'application.
class LocaleProvider extends ChangeNotifier {
  /// Langue par défaut : Français.
  Locale _locale = const Locale('fr');

  Locale get locale => _locale;

  /// Change la langue de l'application vers [locale].
  /// Ne fait rien si [locale] n'est pas dans la liste supportée.
  void setLocale(Locale locale) {
    if (!L10n.all.contains(locale)) return;
    _locale = locale;
    notifyListeners(); // Déclenche la reconstruction du MaterialApp avec la nouvelle locale
  }

  /// Réinitialise la langue vers le français.
  void clearLocale() {
    _locale = const Locale('fr');
    notifyListeners();
  }
}

/// Classe utilitaire listant toutes les locales supportées et leurs noms affichés.
class L10n {
  /// Toutes les locales supportées par l'app — doivent correspondre aux fichiers ARB dans lib/l10n/.
  static final all = [
    const Locale('en'),
    const Locale('fr'),
    const Locale('ar'),
  ];

  /// Retourne le nom lisible pour un code de langue.
  static String getLanguageName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'fr': return 'Français';
      case 'ar': return 'العربية';
      default: return 'Français';
    }
  }
}
