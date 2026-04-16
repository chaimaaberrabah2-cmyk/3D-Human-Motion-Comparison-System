// ============================================================
// lib/core/navigation/navigation_provider.dart
// ============================================================
// Gère l'onglet (page) principal actuellement actif dans l'application.
//
// Ce provider est utilisé par `MainLayout` (qui utilise un IndexedStack)
// pour savoir quelle page afficher. Grâce à l'IndexedStack, changer
// d'onglet ne détruit PAS les pages — elles sont juste cachées/affichées,
// ce qui préserve les états des formulaires, les positions de scroll, etc.
//
// Correspondance index → page :
//   0 → Accueil (HomePage)
//   1 → Historique (HistoryPage)
//   2 → Paramètres (SettingsPage)
//   3 → Nouvelle Analyse (NewAnalysisPage)
//   4 → Établissements (EstablishmentListView - SuperAdmin)
//   5 → Patients (PatientListView - Admin/SuperAdmin)
// ============================================================

import 'package:flutter/material.dart';

/// Classe de gestion d'état pour la navigation entre les onglets principaux.
class NavigationProvider extends ChangeNotifier {
  /// Index de la page actuellement visible
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  /// Passe à l'onglet [index].
  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Helper pour changer d'onglet par nom de route.
  void setIndexByRoute(String route) {
    if (route == '/') setIndex(0);
    else if (route == '/history') setIndex(1);
    else if (route == '/settings') setIndex(2);
    else if (route == '/new_analysis') setIndex(3);
    else if (route == '/establishments') setIndex(4);
    else if (route == '/patients') setIndex(5);
    else if (route == '/calibration') setIndex(6);
  }
}
