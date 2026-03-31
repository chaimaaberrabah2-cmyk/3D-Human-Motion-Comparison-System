import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../navigation/navigation_provider.dart';
import '../../../features/home/presentation/pages/home_page.dart';
import '../../../features/history/presentation/pages/history_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/analysis/presentation/pages/new_analysis_page.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navProvider, child) {
        return IndexedStack(
          index: navProvider.currentIndex,
          children: const [
            HomePage(),
            HistoryPage(),
            SettingsPage(),
            NewAnalysisPage(),
          ],
        );
      },
    );
  }
}
