import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_sidebar.dart';
import '../../../features/admin/presentation/pages/dashboard_view.dart';
import '../../../features/analysis/presentation/pages/new_analysis_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/admin/presentation/pages/establishment_list_view.dart';
import '../../../features/admin/presentation/pages/adherent_list_view.dart';
import '../../../features/history/presentation/pages/history_page.dart';

class SuperAdminLayout extends StatefulWidget {
  const SuperAdminLayout({Key? key}) : super(key: key);

  @override
  State<SuperAdminLayout> createState() => _SuperAdminLayoutState();
}

class _SuperAdminLayoutState extends State<SuperAdminLayout> {
  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<NavigationProvider>().currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: IndexedStack(
              index: _getMappedIndex(currentIndex),
              children: [
                const AdminDashboardView(role: 'super_admin'), // Index 0
                const HistoryPage(),                           // Index 1
                const SettingsPage(),                          // Index 2
                const NewAnalysisPage(),                       // Index 3
                const EstablishmentListView(),                  // Index 4 (Establishments)
                const AdherentListView(),                       // Index 5 (Adhérents)
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Maps the global navigation index to the IndexedStack index
  int _getMappedIndex(int globalIndex) {
    // For now, they are 1:1 since I added indices to NavigationProvider
    if (globalIndex >= 0 && globalIndex <= 5) return globalIndex;
    return 0;
  }

  Widget _buildPlaceholder(String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.construction, color: AppColors.accentBlue, size: 64),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(color: AppColors.textWhite, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Cette fonctionnalité est en cours de développement.",
            style: TextStyle(color: AppColors.textGray),
          ),
        ],
      ),
    );
  }
}
