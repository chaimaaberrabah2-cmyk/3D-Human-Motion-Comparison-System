import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../features/admin/presentation/pages/calibration_editor_view.dart';
import '../navigation/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/admin_sidebar.dart';
import '../../../features/admin/presentation/pages/dashboard_view.dart';
import '../../../features/admin/presentation/pages/patient_list_view.dart';
import '../../../features/analysis/presentation/pages/new_analysis_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/history/presentation/pages/history_page.dart';

class AdminLayout extends StatefulWidget {
  const AdminLayout({Key? key}) : super(key: key);

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _establishmentId = 0;

  @override
  void initState() {
    super.initState();
    _loadEstablishment();
  }

  Future<void> _loadEstablishment() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _establishmentId = prefs.getInt('user_establishment_id') ?? 1;
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
                const PatientListView(),                  // Index 4 (Global 5)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: CalibrationEditorView(establishmentId: _establishmentId), // Index 5 (Global 6)
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getMappedIndex(int globalIndex) {
    if (globalIndex == 5) return 4;
    if (globalIndex == 6) return 5;
    if (globalIndex >= 0 && globalIndex <= 3) return globalIndex;
    return 0;
  }
}
