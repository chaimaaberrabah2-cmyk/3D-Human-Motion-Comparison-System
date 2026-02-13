import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';
import '../widgets/settings_tab_button.dart';
import '../widgets/personal_info_section.dart';
import '../widgets/language_selector.dart';
import '../widgets/settings_actions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/l10n/locale_provider.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedTab = 'Account Profile';
  Locale? _tempLocale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1200;
          final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 1200;

          if (isDesktop || isTablet) {
            // Desktop/Tablet: Sidebar + Settings Content
            return Row(
              children: [
                // Sidebar
                const HomeSidebar(),
                
                // Settings Content
                Expanded(
                  child: _buildSettingsContent(l10n),
                ),
              ],
            );
          } else {
            // Mobile: Drawer + Settings Content
            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                iconTheme: const IconThemeData(color: AppColors.textWhite),
              ),
              drawer: const Drawer(
                child: HomeSidebar(),
              ),
              body: _buildSettingsContent(l10n),
            );
          }
        },
      ),
    );
  }

  Widget _buildSettingsContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              l10n.systemSettings,
              style: const TextStyle(
                color: AppColors.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.systemSettingsDesc,
              style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Responsive Layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return _buildDesktopLayout(l10n);
                } else {
                  return _buildMobileLayout(l10n);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Panel: Tabs
        SizedBox(
          width: 250,
          child: _buildDesktopTabs(l10n),
        ),
        
        const SizedBox(width: 32),
        
        // Right Panel: Content
        Expanded(
          child: _buildDesktopContent(l10n),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Section
        _buildSectionHeader(l10n.accountProfile),
        const SizedBox(height: 16),
        const PersonalInfoSection(),
        const SizedBox(height: 24),
        LanguageSelector(
          onLanguageChanged: (locale) => setState(() => _tempLocale = locale),
        ),
        const SizedBox(height: 32),

        // Calibration Section
        _buildSectionHeader(l10n.cameraCalibration),
        const SizedBox(height: 16),
        // TODO: Implement Calibration Content
        _buildPlaceholder(l10n.cameraCalibration),
        const SizedBox(height: 32),

        // AI Processing Section
        _buildSectionHeader(l10n.aiProcessing),
        const SizedBox(height: 16),
        // TODO: Implement AI Processing Content
        _buildPlaceholder(l10n.aiProcessing),
        const SizedBox(height: 48),

        // Global Actions
        _buildActions(l10n),
      ],
    );
  }

  Widget _buildDesktopTabs(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTabButton(
          iconPath: 'assets/icons/user.svg',
          label: l10n.accountProfile,
          isSelected: selectedTab == 'Account Profile',
          onTap: () => setState(() => selectedTab = 'Account Profile'),
        ),
        const SizedBox(height: 8),
        SettingsTabButton(
          iconPath: 'assets/icons/video.svg',
          label: l10n.cameraCalibration,
          isSelected: selectedTab == 'Camera Calibration',
          onTap: () => setState(() => selectedTab = 'Camera Calibration'),
        ),
        const SizedBox(height: 8),
        SettingsTabButton(
          iconPath: 'assets/icons/processing.svg',
          label: l10n.aiProcessing,
          isSelected: selectedTab == 'Ai Processing',
          onTap: () => setState(() => selectedTab = 'Ai Processing'),
        ),
      ],
    );
  }

  Widget _buildDesktopContent(AppLocalizations l10n) {
    switch (selectedTab) {
      case 'Account Profile':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PersonalInfoSection(),
            const SizedBox(height: 24),
            LanguageSelector(
              onLanguageChanged: (locale) => setState(() => _tempLocale = locale),
            ),
            const SizedBox(height: 32),
            _buildActions(l10n),
          ],
        );
      case 'Camera Calibration':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlaceholder(l10n.cameraCalibration),
             const SizedBox(height: 32),
            _buildActions(l10n),
          ],
        );
      case 'Ai Processing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPlaceholder(l10n.aiProcessing),
             const SizedBox(height: 32),
            _buildActions(l10n),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.accentBlue,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Center(
        child: Text(
          '$title Content Coming Soon',
          style: const TextStyle(color: AppColors.textGray),
        ),
      ),
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return SettingsActions(
      onSave: () {
        if (_tempLocale != null) {
          Provider.of<LocaleProvider>(context, listen: false).setLocale(_tempLocale!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.saveSettings)),
        );
        setState(() {
          _tempLocale = null;
        });
      },
      onDiscard: () {
        setState(() {
          _tempLocale = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discardChanges)),
        );
      },
    );
  }
}
