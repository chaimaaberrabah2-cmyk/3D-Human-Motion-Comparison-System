// ============================================================
// lib/features/home/presentation/widgets/home_sidebar.dart
// ============================================================
// La barre de navigation latérale principale de l'application.
//
// Ce widget affiche :
//   - Le logo et le nom de l'application en haut
//   - Les éléments de navigation (Tableau de bord, Historique, Paramètres)
//   - Détecte et met en surbrillance l'onglet actif grâce à NavigationProvider
//
// Comportement de navigation :
//   - Sur Desktop/Tablette : change directement l'index dans NavigationProvider
//     pour afficher la page correspondante dans le MainLayout (IndexedStack)
//   - Sur Mobile (avec Drawer) : utilise le callback `onNavigate` optionnel
//     pour gérer la navigation via le navigator Flutter
//
// Les icônes sont des fichiers SVG dans assets/icons/
// Les labels sont localisés via AppLocalizations (FR, EN, AR)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/navigation/navigation_provider.dart';

class HomeSidebar extends StatelessWidget {
  final Future<void> Function(String)? onNavigate;

  const HomeSidebar({Key? key, this.onNavigate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Écoute l'index actuel pour mettre à jour la mise en surbrillance des onglets
    final currentIndex = context.watch<NavigationProvider>().currentIndex;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image not found
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.accessibility_new,
                          color: theme.colorScheme.onPrimary,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MOTION AI',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    Text(
                      '3D Pose Analysis',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Éléments de navigation ──────────────────────────────────
          _buildNavItem(
            context,
            iconPath: 'assets/icons/dashboard.svg',
            label: AppLocalizations.of(context)!.dashboard,
            // Actif si l'index est 0 (Accueil) ou 3 (Nouvelle Analyse)
            isSelected: currentIndex == 0 || currentIndex == 3,
            onTap: () async {
              if (onNavigate != null) {
                await onNavigate!('/');
              } else {
                context.read<NavigationProvider>().setIndex(0);
              }
            },
          ),

          _buildNavItem(
            context,
            iconPath: 'assets/icons/historyicon.svg',
            label: AppLocalizations.of(context)!.history,
            isSelected: currentIndex == 1,
            onTap: () async {
              if (onNavigate != null) {
                await onNavigate!('/history');
              } else {
                context.read<NavigationProvider>().setIndex(1);
              }
            },
          ),

          _buildNavItem(
            context,
            iconPath: 'assets/icons/setting.svg',
            label: AppLocalizations.of(context)!.settings,
            isSelected: currentIndex == 2,
            onTap: () async {
              if (onNavigate != null) {
                await onNavigate!('/settings');
              } else {
                context.read<NavigationProvider>().setIndex(2);
              }
            },
          ),

          const Spacer(),

          _buildNavItem(
            context,
            iconData: Icons.logout,
            label: 'Déconnexion',
            isSelected: false,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('user_name');
              await prefs.remove('user_email');
              
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushReplacementNamed('/sign-in');
              }
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    String? iconPath,
    IconData? iconData,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final iconColor = isSelected
        ? theme.primaryColor
        : (theme.textTheme.bodyMedium?.color ?? Colors.grey);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? theme.primaryColor.withValues(alpha: 0.2)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                if (iconPath != null)
                  SvgPicture.asset(
                    iconPath,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                  )
                else if (iconData != null)
                  Icon(
                    iconData,
                    size: 20,
                    color: iconColor,
                  ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? theme.primaryColor
                        : theme.textTheme.bodyLarge?.color,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
