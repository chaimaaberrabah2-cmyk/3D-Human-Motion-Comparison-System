// ============================================================
// lib/core/pages/main_layout.dart
// ============================================================
// C'est la COQUE PRINCIPALE de toutes les pages authentifiées.
//
// Il utilise un `IndexedStack` qui garde les 4 pages principales
// en mémoire simultanément. La page active est affichée, les autres
// sont cachées — mais PAS détruites. Ceci signifie :
//   ✅ Les données de formulaire sont préservées lors du changement d'onglet
//   ✅ Les positions de défilement sont mémorisées
//   ✅ Pas de coût de reconstruction de page lors du changement d'onglet
//
// La page affichée est contrôlée par `NavigationProvider`.
// La barre latérale (HomeSidebar) met à jour NavigationProvider
// quand l'utilisateur clique sur un autre onglet.
//
// Pages dans la pile :
//   index 0 → HomePage      (Accueil)
//   index 1 → HistoryPage   (Historique)
//   index 2 → SettingsPage  (Paramètres)
//   index 3 → NewAnalysisPage (Nouvelle Analyse)
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../navigation/navigation_provider.dart';
import '../../../features/home/presentation/pages/home_page.dart';
import '../../../features/history/presentation/pages/history_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/analysis/presentation/pages/new_analysis_page.dart';
import '../../../features/home/presentation/widgets/home_sidebar.dart';

/// Widget racine affiché après la connexion de l'utilisateur standard.
/// Agit comme une coque persistante contenant toutes les pages principales.
class MainLayout extends StatelessWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        final content = IndexedStack(
          index: navProvider.currentIndex,
          children: const [
            HomePage(),        // index 0 — Accueil
            HistoryPage(),     // index 1 — Historique
            SettingsPage(),    // index 2 — Paramètres
            NewAnalysisPage(), // index 3 — Nouvelle Analyse
          ],
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1200;
            final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

            if (isDesktop || isTablet) {
              // Desktop/Tablet: Sidebar + Main Content
              return Scaffold(
                body: Row(
                  children: [
                    const HomeSidebar(),
                    Expanded(child: content),
                  ],
                ),
              );
            } else {
              // Mobile: Drawer + Main Content
              return Scaffold(
                appBar: AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  iconTheme: Theme.of(context).iconTheme,
                ),
                drawer: const Drawer(
                  child: HomeSidebar(),
                ),
                body: SafeArea(child: content),
              );
            }
          },
        );
      },
    );
  }
}
