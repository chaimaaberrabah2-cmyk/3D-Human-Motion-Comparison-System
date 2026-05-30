import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../navigation/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_sidebar.dart';
import '../../../features/admin/presentation/pages/dashboard_view.dart';
import '../../../features/admin/presentation/pages/adherent_list_view.dart';
import '../../../features/analysis/presentation/pages/new_analysis_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/history/presentation/pages/history_page.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({Key? key}) : super(key: key);

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int? _establishmentId;

  @override
  void initState() {
    super.initState();
    _loadEstablishment();
  }

  Future<void> _loadEstablishment() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('user_establishment_id');
    if (!mounted) return;
    setState(() {
      _establishmentId = (id != null && id > 0) ? id : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Current Global Index from NavigationProvider
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
                const AdminDashboardView(role: 'admin'), // Index 0
                const HistoryPage(),                      // Index 1
                const SettingsPage(),                     // Index 2
                const NewAnalysisPage(),                  // Index 3
                AdherentListView(
                  key: ValueKey('adherents_${_establishmentId ?? 0}'),
                  establishmentId: _establishmentId,
                ),                                        // Index 4 (Global 5)
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getMappedIndex(int globalIndex) {
    if (globalIndex == 5) return 4;
    if (globalIndex >= 0 && globalIndex <= 3) return globalIndex;
    return 0;
  }
}
