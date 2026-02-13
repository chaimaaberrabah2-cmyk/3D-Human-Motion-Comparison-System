// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Motion AI';

  @override
  String get systemSettings => 'Paramètres Système';

  @override
  String get systemSettingsDesc =>
      'Gérez votre matériel MotionAI, vos modèles IA et vos préférences de compte.';

  @override
  String get accountProfile => 'Profil';

  @override
  String get cameraCalibration => 'Calibration Caméra';

  @override
  String get aiProcessing => 'Traitement IA';

  @override
  String get personalInformation => 'Informations Personnelles';

  @override
  String get user => 'Utilisateur';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get language => 'Langue';

  @override
  String get light => 'Clair';

  @override
  String get discardChanges => 'Annuler les Modifications';

  @override
  String get saveSettings => 'Enregistrer';

  @override
  String welcomeBack(String username) {
    return 'Bon retour, $username';
  }

  @override
  String get startNewAnalysis => 'Nouvelle Analyse';

  @override
  String get searchExercises => 'Rechercher des exercices...';

  @override
  String get all => 'Tous';

  @override
  String get strength => 'Force';

  @override
  String get mobility => 'Mobilité';

  @override
  String get bodyWeight => 'Poids du Corps';

  @override
  String get rehab => 'Rééducation';

  @override
  String get dashboard => 'Tableau de Bord';

  @override
  String get settings => 'Paramètres';
}
