import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Motion AI'**
  String get appTitle;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get systemSettings;

  /// No description provided for @systemSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your MotionAI hardware, AI models, and account preferences.'**
  String get systemSettingsDesc;

  /// No description provided for @accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Account Profile'**
  String get accountProfile;

  /// No description provided for @cameraCalibration.
  ///
  /// In en, this message translates to:
  /// **'Camera Calibration'**
  String get cameraCalibration;

  /// No description provided for @aiProcessing.
  ///
  /// In en, this message translates to:
  /// **'Ai Processing'**
  String get aiProcessing;

  /// No description provided for @personalInformation.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get personalInformation;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes'**
  String get discardChanges;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {username}'**
  String welcomeBack(String username);

  /// No description provided for @startNewAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start New Analysis'**
  String get startNewAnalysis;

  /// No description provided for @searchExercises.
  ///
  /// In en, this message translates to:
  /// **'Search exercises...'**
  String get searchExercises;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strength;

  /// No description provided for @mobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get mobility;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'BodyWeight'**
  String get bodyWeight;

  /// No description provided for @rehab.
  ///
  /// In en, this message translates to:
  /// **'Rehab'**
  String get rehab;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @deepLearningBackend.
  ///
  /// In en, this message translates to:
  /// **'Deep Learning Backend'**
  String get deepLearningBackend;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @calibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated'**
  String get calibrated;

  /// No description provided for @processingModel.
  ///
  /// In en, this message translates to:
  /// **'Processing Model'**
  String get processingModel;

  /// No description provided for @performanceMode.
  ///
  /// In en, this message translates to:
  /// **'Performance Mode'**
  String get performanceMode;

  /// No description provided for @computingDevice.
  ///
  /// In en, this message translates to:
  /// **'Computing Device'**
  String get computingDevice;

  /// No description provided for @highAccuracy.
  ///
  /// In en, this message translates to:
  /// **'High Accuracy'**
  String get highAccuracy;

  /// No description provided for @balanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get balanced;

  /// No description provided for @highSpeed.
  ///
  /// In en, this message translates to:
  /// **'High Speed'**
  String get highSpeed;

  /// No description provided for @modifyCamera.
  ///
  /// In en, this message translates to:
  /// **'Modify {cameraName}'**
  String modifyCamera(String cameraName);

  /// No description provided for @updateDeviceSource.
  ///
  /// In en, this message translates to:
  /// **'Update device source and calibration parameters'**
  String get updateDeviceSource;

  /// No description provided for @chooseCameraSource.
  ///
  /// In en, this message translates to:
  /// **'1. CHOOSE CAMERA SOURCE'**
  String get chooseCameraSource;

  /// No description provided for @addCalibrationData.
  ///
  /// In en, this message translates to:
  /// **'2. ADD CALIBRATION DATA'**
  String get addCalibrationData;

  /// No description provided for @clickToUpload.
  ///
  /// In en, this message translates to:
  /// **'Click to upload calibration file'**
  String get clickToUpload;

  /// No description provided for @uploadDesc.
  ///
  /// In en, this message translates to:
  /// **'or drag and drop your .bin or .json file here'**
  String get uploadDesc;

  /// No description provided for @applyChanges.
  ///
  /// In en, this message translates to:
  /// **'Apply Changes'**
  String get applyChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @aiEngineDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the AI engine for keypoint extraction and SMPL fitting.'**
  String get aiEngineDescription;

  /// No description provided for @legacyPose2DEngine.
  ///
  /// In en, this message translates to:
  /// **'Lagacy Pose2D Engine'**
  String get legacyPose2DEngine;

  /// No description provided for @legacyPose2DDesc.
  ///
  /// In en, this message translates to:
  /// **'Faster processing, reduced spatial accuracy.'**
  String get legacyPose2DDesc;

  /// No description provided for @deepLearningBackendDesc.
  ///
  /// In en, this message translates to:
  /// **'Optimized for high-fidelity posture tracking.'**
  String get deepLearningBackendDesc;

  /// No description provided for @newMultiViewAnalysis.
  ///
  /// In en, this message translates to:
  /// **'New Multi-View Analysis'**
  String get newMultiViewAnalysis;

  /// No description provided for @newAnalysisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload synchronized video streams for 3D reconstruction and SMPL modeling'**
  String get newAnalysisSubtitle;

  /// No description provided for @captureMethod.
  ///
  /// In en, this message translates to:
  /// **'CAPTURE METHOD'**
  String get captureMethod;

  /// No description provided for @uploadStreams.
  ///
  /// In en, this message translates to:
  /// **'UPLOAD STREAMS'**
  String get uploadStreams;

  /// No description provided for @syncAndProcess.
  ///
  /// In en, this message translates to:
  /// **'SYNC & PROCESS'**
  String get syncAndProcess;

  /// No description provided for @uploadFiles.
  ///
  /// In en, this message translates to:
  /// **'Upload Files'**
  String get uploadFiles;

  /// No description provided for @uploadFilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Upload existing synchronized video files from up to 4 camera angles.'**
  String get uploadFilesDesc;

  /// No description provided for @liveMultiCam.
  ///
  /// In en, this message translates to:
  /// **'Live Multi-Cam'**
  String get liveMultiCam;

  /// No description provided for @liveMultiCamDesc.
  ///
  /// In en, this message translates to:
  /// **'Stream directly from connected cameras for real-time analysis.'**
  String get liveMultiCamDesc;

  /// No description provided for @analysisInfoBanner.
  ///
  /// In en, this message translates to:
  /// **'For best results, ensure all cameras share the same frame rate and are calibrated using the provided calibration pattern.'**
  String get analysisInfoBanner;

  /// No description provided for @cameraAngleFront.
  ///
  /// In en, this message translates to:
  /// **'Camera Angle 1 - Front'**
  String get cameraAngleFront;

  /// No description provided for @cameraAngleLeft.
  ///
  /// In en, this message translates to:
  /// **'Camera angle 2 - Left'**
  String get cameraAngleLeft;

  /// No description provided for @cameraAngleBack.
  ///
  /// In en, this message translates to:
  /// **'Camera Angle 3 - Back'**
  String get cameraAngleBack;

  /// No description provided for @cameraAngleRight.
  ///
  /// In en, this message translates to:
  /// **'Camera Angle 4 - Right'**
  String get cameraAngleRight;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
