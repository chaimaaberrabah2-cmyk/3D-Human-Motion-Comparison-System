import 'package:flutter/material.dart';
import '../../../home/presentation/widgets/home_sidebar.dart';
import '../widgets/settings_tab_button.dart';
import '../widgets/personal_info_section.dart';
import '../widgets/language_selector.dart';
import '../widgets/settings_actions.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String selectedTab = 'Account Profile';

  @override
  Widget build(BuildContext context) {
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
                  child: _buildSettingsContent(),
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
              body: _buildSettingsContent(),
            );
          }
        },
      ),
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'System Settings',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your MotionAI hardware, AI models, and account preferences.',
              style: TextStyle(
                color: AppColors.textGray,
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Settings Layout
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  // Desktop: Side-by-side layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Panel: Tabs
                      SizedBox(
                        width: 250,
                        child: _buildTabsPanel(),
                      ),
                      
                      const SizedBox(width: 32),
                      
                      // Right Panel: Content
                      Expanded(
                        child: _buildContentPanel(),
                      ),
                    ],
                  );
                } else {
                  // Mobile/Tablet: Stacked layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTabsPanel(),
                      const SizedBox(height: 24),
                      _buildContentPanel(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsTabButton(
          iconPath: 'assets/icons/dashboard.svg', // TODO: Add account icon
          label: 'Account Profile',
          isSelected: selectedTab == 'Account Profile',
          onTap: () {
            setState(() {
              selectedTab = 'Account Profile';
            });
          },
        ),
        const SizedBox(height: 8),
        SettingsTabButton(
          iconPath: 'assets/icons/dashboard.svg', // TODO: Add camera icon
          label: 'Camera Calibration',
          isSelected: selectedTab == 'Camera Calibration',
          onTap: () {
            setState(() {
              selectedTab = 'Camera Calibration';
            });
          },
        ),
        const SizedBox(height: 8),
        SettingsTabButton(
          iconPath: 'assets/icons/dashboard.svg', // TODO: Add AI icon
          label: 'Ai Processing',
          isSelected: selectedTab == 'Ai Processing',
          onTap: () {
            setState(() {
              selectedTab = 'Ai Processing';
            });
          },
        ),
      ],
    );
  }

  Widget _buildContentPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal Information Section
        const PersonalInfoSection(),
        
        // Language Selector
        const LanguageSelector(),
        
        const SizedBox(height: 32),
        
        // Action Buttons
        SettingsActions(
          onSave: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings saved!')),
            );
          },
          onDiscard: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Changes discarded')),
            );
          },
        ),
      ],
    );
  }
}
