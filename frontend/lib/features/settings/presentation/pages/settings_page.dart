// ============================================================
// lib/features/settings/presentation/pages/settings_page.dart
// ============================================================
// Page des paramètres de l'application.
//
// Permet à l'utilisateur de configurer :
//   - Son profil (Informations personnelles, Changer de mot de passe)
//   - L'application (Langue FR/EN/AR, Thème Sombre/Clair, Déconnexion)
//
// Structure :
//   Affiche uniquement le profil utilisateur. Les onglets Calibration
//   et Traitement IA ont été retirés de l'interface.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/navigation/navigation_provider.dart';
import '../widgets/personal_info_section.dart';
import '../../../../core/theme/theme_provider.dart';
import '../widgets/language_selector.dart';
import '../widgets/settings_actions.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _role = 'user';

  // Track original values on page load
  Locale? _originalLocale;
  bool? _originalIsDarkMode;

  // Track if changes were made
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Capture original values when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final localeProvider =
          Provider.of<LocaleProvider>(context, listen: false);
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      _loadRole();
      setState(() {
        _originalLocale = localeProvider.locale;
        _originalIsDarkMode = themeProvider.isDarkMode;
      });
    });
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _role = prefs.getString('user_role') ?? 'user';
      });
    }
  }

  @override
  void dispose() {
    // Revert if navigating away with unsaved changes
    if (_hasUnsavedChanges) {
      _revertChanges();
    }
    super.dispose();
  }

  void _revertChanges() {
    if (_originalLocale != null) {
      Provider.of<LocaleProvider>(context, listen: false)
          .setLocale(_originalLocale!);
    }
    if (_originalIsDarkMode != null) {
      Provider.of<ThemeProvider>(context, listen: false)
          .toggleTheme(_originalIsDarkMode!);
    }
  }

  Future<String?> _showUnsavedChangesDialog() async {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.unsavedChangesTitle),
        content: Text(l10n.unsavedChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(l10n.discardAndContinue),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(l10n.saveAndContinue),
          ),
        ],
      ),
    );
  }

  void _onSave() {
    // Update original values to current
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    setState(() {
      _originalLocale = localeProvider.locale;
      _originalIsDarkMode = themeProvider.isDarkMode;
      _hasUnsavedChanges = false;
    });
  }

  void _onDiscard() {
    _revertChanges();
    setState(() => _hasUnsavedChanges = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final action = await _showUnsavedChangesDialog();

        if (action == 'save' && context.mounted) {
          _onSave();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // At root, go back to Dashboard
            context.read<NavigationProvider>().setIndex(0);
          }
        } else if (action == 'discard' && context.mounted) {
          _revertChanges();
          setState(() => _hasUnsavedChanges = false);
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // At root, go back to Dashboard
            context.read<NavigationProvider>().setIndex(0);
          }
        }
      },
      child: _buildSettingsContent(l10n),
    );
  }

  Widget _buildSettingsContent(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.systemSettings,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.systemSettingsDesc,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Profile Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PersonalInfoSection(),
                const SizedBox(height: 24),
                LanguageSelector(
                  onLanguageChanged: (locale) {
                    setState(() => _hasUnsavedChanges = true);
                  },
                  onThemeChanged: (isDark) {
                    setState(() => _hasUnsavedChanges = true);
                  },
                ),
                const SizedBox(height: 32),
                _buildActions(l10n),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return SettingsActions(
      onSave: () {
        _onSave();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveSettings)),
        );
      },
      onDiscard: () {
        _onDiscard();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discardChanges)),
        );
      },
    );
  }
}
