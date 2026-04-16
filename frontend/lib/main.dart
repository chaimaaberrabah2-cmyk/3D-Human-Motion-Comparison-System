// ============================================================
// lib/main.dart — Point d'entrée de l'application
// ============================================================
// Ce fichier démarre toute l'application Flutter. Il fait ce qui suit :
//
// 1. Enveloppe l'application dans un `MultiProvider` pour que les classes
//    de gestion d'état (LocaleProvider, ThemeProvider, NavigationProvider)
//    soient accessibles à tous les widgets de l'arbre.
//
// 2. Utilise `Consumer2` pour reconstruire le `MaterialApp` à chaque
//    changement de langue ou de thème, assurant une réaction instantanée de l'UI.
//
// 3. Définit `initialRoute` ('/sign-in') — le premier écran visible
//    au lancement est donc la page de connexion.
//
// 4. Liste toutes les routes nommées dans `onGenerateRoute` — c'est
//    la table de routage centrale de toute l'app.
//
// Table des routes :
//   /sign-in         → SignInPage (connexion)
//   /                → MainLayout (Accueil, Historique, Paramètres, Analyse)
//   /starting        → StartingPage (page de bienvenue)
//   /sign-up         → SignUpPage (inscription)
//   /forgot-password → ForgotPasswordPage (mot de passe oublié)
//   /reset-password  → ResetPasswordPage (réinitialisation)
//   /new-password    → NewPasswordPage (nouveau mot de passe)
//   /success         → SuccessPage (confirmation)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/l10n/locale_provider.dart';
import 'core/navigation/navigation_provider.dart';
import 'core/presentation/pages/main_layout.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/authentification/presentation/pages/forgot_password_page.dart';
import 'features/authentification/presentation/pages/new_password_page.dart';
import 'features/authentification/presentation/pages/reset_password_page.dart';
import 'features/authentification/presentation/pages/sign_in_page.dart';
import 'features/authentification/presentation/pages/sign_up_page.dart';
import 'features/authentification/presentation/pages/starting_page.dart';
import 'features/authentification/presentation/pages/success_page.dart';
import 'features/authentification/presentation/pages/body_profile_page.dart';
import 'core/presentation/pages/admin_layout.dart';
import 'core/presentation/pages/super_admin_layout.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const MotionAIApp());
}

class MotionAIApp extends StatelessWidget {
  const MotionAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Gère la langue active de l'application (fr, en, ar)
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        // Gère le thème sombre/clair, persisté dans SharedPreferences
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Gère l'onglet principal sélectionné (Accueil, Historique, Paramètres, Analyse)
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
              // Premier écran affiché à l'utilisateur au démarrage
              initialRoute: '/sign-in',
              onGenerateRoute: (settings) {
                Widget page;
                switch (settings.name) {
                  case '/sign-in':
                    page = const SignInPage();
                    break;
                  case '/':
                    // MainLayout contient tous les onglets principaux via un IndexedStack
                    // → aucune page n'est détruite lors du changement d'onglet (User Standard)
                    page = const MainLayout();
                    break;
                  case '/admin':
                    page = const AdminLayout();
                    break;
                  case '/super-admin':
                    page = const SuperAdminLayout();
                    break;
                  case '/starting':
                    page = const StartingPage();
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
                  case '/body-profile':
                    page = const BodyProfilePage();
                    break;
                  default:
                    page = const SignInPage();
                }

                // Transitions instantanées entre les pages (sans animation)
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
