// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Motion AI';

  @override
  String get systemSettings => 'System Settings';

  @override
  String get systemSettingsDesc =>
      'Manage your MotionAI hardware, AI models, and account preferences.';

  @override
  String get accountProfile => 'Account Profile';

  @override
  String get cameraCalibration => 'Camera Calibration';

  @override
  String get aiProcessing => 'Ai Processing';

  @override
  String get personalInformation => 'Personal Information';

  @override
  String get user => 'User';

  @override
  String get changePassword => 'Change password';

  @override
  String get language => 'Language';

  @override
  String get light => 'Light';

  @override
  String get discardChanges => 'Discard Changes';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String welcomeBack(String username) {
    return 'Welcome back, $username';
  }

  @override
  String get startNewAnalysis => 'Start New Analysis';

  @override
  String get searchExercises => 'Search exercises...';

  @override
  String get all => 'All';

  @override
  String get strength => 'Strength';

  @override
  String get mobility => 'Mobility';

  @override
  String get bodyWeight => 'BodyWeight';

  @override
  String get rehab => 'Rehab';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get settings => 'Settings';
}
