import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'features/authentification/presentation/pages/sign_in_page.dart';
import 'features/authentification/presentation/pages/sign_up_page.dart';
import 'features/authentification/presentation/pages/forgot_password_page.dart';
import 'features/authentification/presentation/pages/reset_password_page.dart';
import 'features/authentification/presentation/pages/new_password_page.dart';
import 'features/authentification/presentation/pages/success_page.dart';
import 'features/authentification/presentation/pages/starting_page.dart';
import 'core/l10n/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/navigation_provider.dart';
import 'core/presentation/pages/main_layout.dart';

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
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
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
              initialRoute: '/starting',
              onGenerateRoute: (settings) {
                Widget page;
                switch (settings.name) {
                  case '/starting':
                    page = const StartingPage();
                    break;
                  case '/sign-in':
                    page = const SignInPage();
                    break;
                  case '/sign-up':
                    page = const SignUpPage();
                    break;
                  case '/forgot-password':
                    page = const ForgotPasswordPage();
                    break;
                  case '/reset-password':
                    page = const ResetPasswordPage();
                    break;
                  case '/new-password':
                    page = const NewPasswordPage();
                    break;
                  case '/success':
                    page = const SuccessPage();
                    break;
                  case '/':
                    // Root is now MainLayout which handles all the tab switching
                    page = const MainLayout();
                    break;
                  // We can remove individual routed pages that are now tabs
                  // because they will be shown inside MainLayout
                  case '/history':
                    page = const MainLayout(); // Fallback if pushed
                    break;
                  case '/settings':
                    page = const MainLayout();
                    break;
                  case '/new_analysis':
                    page = const MainLayout();
                    break;
                  default:
                    page = const StartingPage();
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
