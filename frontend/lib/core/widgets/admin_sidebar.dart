import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../l10n/app_localizations.dart';
import '../../core/navigation/navigation_provider.dart';
import '../theme/app_colors.dart';

class AdminSidebar extends StatefulWidget {
  const AdminSidebar({Key? key}) : super(key: key);

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  String _role = 'user';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('user_role') ?? 'user';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIndex = context.watch<NavigationProvider>().currentIndex;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.shield, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _role == 'super_admin' ? 'SUPER ADMIN' : 'CLUB ADMIN',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    Text(
                      'Monitoring Panel',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Dashboard (Index 0) ──────────────────────────────────
          _buildNavItem(
            context,
            iconData: Icons.dashboard_rounded,
            label: "Dashboard",
            isSelected: currentIndex == 0,
            onTap: () => context.read<NavigationProvider>().setIndex(0),
          ),

          // ── Pour Super Admin : Liste des Établissements (Index 4) ─────
          if (_role == 'super_admin')
            _buildNavItem(
              context,
              iconData: Icons.business_rounded,
              label: "Établissements",
              isSelected: currentIndex == 4,
              onTap: () => context.read<NavigationProvider>().setIndex(4),
            ),

          // ── Pour Admin : Mes Adhérents (Index 5) ──────────────────────
          if (_role == 'admin') // Masqué pour le Super Admin (accessible via Établissements)
            _buildNavItem(
              context,
              iconData: Icons.people_alt_rounded,
              label: "Liste des Adhérents",
              isSelected: currentIndex == 5,
              onTap: () => context.read<NavigationProvider>().setIndex(5),
            ),

          const Divider(color: AppColors.sidebarSeparator, indent: 20, endIndent: 20, height: 40),

          // ── Faire une Analyse (Index 3) ─────────────────────────────
          if (_role != 'super_admin')
            _buildNavItem(
              context,
              iconData: Icons.play_circle_fill_rounded,
              label: "Nouvelle Analyse",
              isSelected: currentIndex == 3,
              onTap: () => context.read<NavigationProvider>().setIndex(3),
            ),

          // ── Historique (Index 1) ──────────────────────────────────
          if (_role != 'super_admin')
            _buildNavItem(
              context,
              iconData: Icons.history_rounded,
              label: _role == 'admin' ? "Mon Historique" : "Historique Global",
              isSelected: currentIndex == 1,
              onTap: () => context.read<NavigationProvider>().setIndex(1),
            ),


          // ── Paramètres (Index 2) ──────────────────────────────────
          _buildNavItem(
            context,
            iconData: Icons.settings_rounded,
            label: "Configuration",
            isSelected: currentIndex == 2,
            onTap: () => context.read<NavigationProvider>().setIndex(2),
          ),

          const Spacer(),

          // ── Logout ───────────────────────────────────────────────
          _buildNavItem(
            context,
            iconData: Icons.logout_rounded,
            label: "Déconnexion",
            isSelected: false,
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
    IconData? iconData,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final iconColor = isSelected ? AppColors.accentBlue : AppColors.textGray;

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
              color: isSelected ? AppColors.accentBlue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.accentBlue.withOpacity(0.2) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(iconData, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? AppColors.textWhite : AppColors.textGray,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
