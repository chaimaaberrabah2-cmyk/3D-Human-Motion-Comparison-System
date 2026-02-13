import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';
import '../widgets/settings_tab_button.dart';
import '../widgets/personal_info_section.dart';
import '../widgets/camera_calibration_section.dart';
import '../widgets/ai_processing_section.dart';
import '../../../../core/theme/theme_provider.dart';
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
    
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                backgroundColor: theme.scaffoldBackgroundColor,
                elevation: 0,
                iconTheme: theme.iconTheme,
              ),
              drawer: const Drawer(
                child: HomeSidebar(),
              ),
              body: SafeArea(
                child: _buildSettingsContent(l10n),
              ),
            );
          }
        },
      ),
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
        
        // Responsive Layout Content
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return _buildDesktopLayout(l10n);
              } else {
                return _buildMobileLayout(l10n);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Fixed Tabs
          SizedBox(
            width: 250,
            child: _buildDesktopTabs(l10n),
          ),
          
          const SizedBox(width: 32),
          
          // Right Panel: Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: _buildDesktopContent(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Scrollable Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMobileTab(
                  l10n.accountProfile,
                  'Account Profile',
                  'assets/icons/user.svg',
                ),
                const SizedBox(width: 12),
                _buildMobileTab(
                  l10n.cameraCalibration,
                  'Camera Calibration',
                  'assets/icons/video.svg',
                ),
                const SizedBox(width: 12),
                _buildMobileTab(
                  l10n.aiProcessing,
                  'Ai Processing',
                  'assets/icons/processing.svg',
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
  
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: _buildDesktopContent(l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTab(String label, String id, String iconPath) {
    final isSelected = selectedTab == id;
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: () => setState(() => selectedTab = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : theme.dividerColor,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: theme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(
                isSelected ? theme.colorScheme.onPrimary : (theme.textTheme.bodyMedium?.color ?? Colors.grey),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
            const CameraCalibrationSection(),
             const SizedBox(height: 32),
            _buildActions(l10n),
          ],
        );
      case 'Ai Processing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiProcessingSection(),
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
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Center(
        child: Text(
          '$title Content Coming Soon',
          style: theme.textTheme.bodyMedium,
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
        // Reset to default settings (English & Dark Mode)
        setState(() {
          _tempLocale = null;
        });
        
        // Reset Locale to English
        Provider.of<LocaleProvider>(context, listen: false).setLocale(const Locale('en'));
        
        // Reset Theme to Dark Mode
        Provider.of<ThemeProvider>(context, listen: false).toggleTheme(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.discardChanges)),
        );
      },
    );
  }
}
