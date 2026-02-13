import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/analysis/presentation/pages/new_analysis_page.dart';
import 'core/l10n/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const MotionAIApp());
}

class MotionAIApp extends StatelessWidget {
  const MotionAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer2<LocaleProvider, ThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: MaterialApp(
              title: 'Motion AI',
              debugShowCheckedModeBanner: false,
              locale: localeProvider.locale,
              supportedLocales: L10n.all,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              onGenerateRoute: (settings) {
                Widget page;
                switch (settings.name) {
                  case '/':
                    page = const HomePage();
                    break;
                  case '/settings':
                    page = const SettingsPage();
                    break;
                  case '/new_analysis':
                    page = const NewAnalysisPage();
                    break;
                  default:
                    page = const HomePage();
                }
                
                // Return route without animation
                return PageRouteBuilder(
                  settings: settings,
                  pageBuilder: (context, animation, secondaryAnimation) => page,
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
