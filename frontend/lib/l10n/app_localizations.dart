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

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAllRecords.
  ///
  /// In en, this message translates to:
  /// **'View All Records'**
  String get viewAllRecords;

  /// No description provided for @totalSessions.
  ///
  /// In en, this message translates to:
  /// **'Total Sessions'**
  String get totalSessions;

  /// No description provided for @avgAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Avg. Accuracy'**
  String get avgAccuracy;

  /// No description provided for @processingTime.
  ///
  /// In en, this message translates to:
  /// **'Processing Time'**
  String get processingTime;

  /// No description provided for @activeCameras.
  ///
  /// In en, this message translates to:
  /// **'Active Cameras'**
  String get activeCameras;

  /// No description provided for @sessionId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionId;

  /// No description provided for @dateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateTime;

  /// No description provided for @deviceSource.
  ///
  /// In en, this message translates to:
  /// **'Device Source'**
  String get deviceSource;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @score.
  ///
  /// In en, this message translates to:
  /// **'SCORE'**
  String get score;

  /// No description provided for @performancePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get performancePreview;

  /// No description provided for @completedStatus.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatus;

  /// No description provided for @failedStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedStatus;

  /// No description provided for @stable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get stable;

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
  /// **'ADD CALIBRATION DATA'**
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

  /// No description provided for @addNewCamera.
  ///
  /// In en, this message translates to:
  /// **'Add New Camera'**
  String get addNewCamera;

  /// No description provided for @deleteCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Camera?'**
  String get deleteCameraTitle;

  /// No description provided for @deleteCameraMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {cameraName}? This action cannot be undone.'**
  String deleteCameraMessage(String cameraName);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @minimumCamerasWarning.
  ///
  /// In en, this message translates to:
  /// **'You must have at least 4 cameras'**
  String get minimumCamerasWarning;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'(Language)'**
  String get languageLabel;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. What would you like to do?'**
  String get unsavedChangesMessage;

  /// No description provided for @saveAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get saveAndContinue;

  /// No description provided for @discardAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Discard & Continue'**
  String get discardAndContinue;

  /// No description provided for @cameraSource.
  ///
  /// In en, this message translates to:
  /// **'Camera Source'**
  String get cameraSource;

  /// No description provided for @calibrationFile.
  ///
  /// In en, this message translates to:
  /// **'Calibration File'**
  String get calibrationFile;

  /// No description provided for @uploadCalibration.
  ///
  /// In en, this message translates to:
  /// **'Upload Calibration'**
  String get uploadCalibration;

  /// No description provided for @dragDropHint.
  ///
  /// In en, this message translates to:
  /// **'or drag and drop your .bin or .json file here'**
  String get dragDropHint;

  /// No description provided for @statusCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Status: Calibrated'**
  String get statusCalibrated;

  /// No description provided for @aiAlgorithm.
  ///
  /// In en, this message translates to:
  /// **'AI Algorithm'**
  String get aiAlgorithm;

  /// No description provided for @blazePose.
  ///
  /// In en, this message translates to:
  /// **'MediaPipe (BlazePose)'**
  String get blazePose;

  /// No description provided for @openPose.
  ///
  /// In en, this message translates to:
  /// **'OpenPose'**
  String get openPose;

  /// No description provided for @yolo.
  ///
  /// In en, this message translates to:
  /// **'YOLO'**
  String get yolo;

  /// No description provided for @pavllo.
  ///
  /// In en, this message translates to:
  /// **'Pavllo'**
  String get pavllo;

  /// No description provided for @blazePoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast & lightweight. Best for real-time mobile use.'**
  String get blazePoseDesc;

  /// No description provided for @openPoseDesc.
  ///
  /// In en, this message translates to:
  /// **'High accuracy. Resource heavy.'**
  String get openPoseDesc;

  /// No description provided for @yoloDesc.
  ///
  /// In en, this message translates to:
  /// **'Rapid object & pose detection. Balanced speed/accuracy.'**
  String get yoloDesc;

  /// No description provided for @pavlloDesc.
  ///
  /// In en, this message translates to:
  /// **'Specialized 3D human pose lifting from 2D video.'**
  String get pavlloDesc;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start Recording'**
  String get startRecording;

  /// No description provided for @rec.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get rec;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @newAnalysis.
  ///
  /// In en, this message translates to:
  /// **'New Analysis'**
  String get newAnalysis;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select exercice'**
  String get selectExercise;

  /// No description provided for @pleaseSelectExercise.
  ///
  /// In en, this message translates to:
  /// **'Please select your reference exercice'**
  String get pleaseSelectExercise;

  /// No description provided for @userReconstruction.
  ///
  /// In en, this message translates to:
  /// **'USER RECONSTRUCTION'**
  String get userReconstruction;

  /// No description provided for @analysisResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Results'**
  String get analysisResultsTitle;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @exportingPdfMessage.
  ///
  /// In en, this message translates to:
  /// **'Exporting PDF... (Feature in development)'**
  String get exportingPdfMessage;

  /// No description provided for @syncVideoStreams.
  ///
  /// In en, this message translates to:
  /// **'Synchronizing video streams...'**
  String get syncVideoStreams;

  /// No description provided for @extractingKeypoints.
  ///
  /// In en, this message translates to:
  /// **'Extracting 2D keypoints (BlazePose)...'**
  String get extractingKeypoints;

  /// No description provided for @fittingSmpl.
  ///
  /// In en, this message translates to:
  /// **'Fitting SMPL-X body model...'**
  String get fittingSmpl;

  /// No description provided for @optimizingMesh.
  ///
  /// In en, this message translates to:
  /// **'Optimizing 3D mesh reconstruction...'**
  String get optimizingMesh;

  /// No description provided for @generatingReports.
  ///
  /// In en, this message translates to:
  /// **'Generating comparison reports...'**
  String get generatingReports;

  /// No description provided for @remainingTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining time: {time}s'**
  String remainingTimeLabel(int time);

  /// No description provided for @logAnalysisStarted.
  ///
  /// In en, this message translates to:
  /// **'ANALYSIS STARTED'**
  String get logAnalysisStarted;

  /// No description provided for @logSyncOk.
  ///
  /// In en, this message translates to:
  /// **'SYCHRONIZING STREAMS - OK'**
  String get logSyncOk;

  /// No description provided for @logExtractionProgress.
  ///
  /// In en, this message translates to:
  /// **'KEYPOINT EXTRACTION IN PROGRESS'**
  String get logExtractionProgress;

  /// No description provided for @logSmplActive.
  ///
  /// In en, this message translates to:
  /// **'SMPL-X MESH FITTING ACTIVE'**
  String get logSmplActive;

  /// No description provided for @analysisFeedback.
  ///
  /// In en, this message translates to:
  /// **'Comparing your movement with {exerciseName}. Initial analysis shows 85% form accuracy. Focus on lowering your hips further during the eccentric phase.'**
  String analysisFeedback(String exerciseName);

  /// No description provided for @strengthAnalysisMode.
  ///
  /// In en, this message translates to:
  /// **'Strength Analysis Mode'**
  String get strengthAnalysisMode;

  /// No description provided for @mobilityAnalysisMode.
  ///
  /// In en, this message translates to:
  /// **'Mobility Analysis Mode'**
  String get mobilityAnalysisMode;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @instructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructionsLabel;

  /// No description provided for @motionVisualization.
  ///
  /// In en, this message translates to:
  /// **'3D Motion Visualization'**
  String get motionVisualization;

  /// No description provided for @motionVisualizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ideal motion comparison will appear here'**
  String get motionVisualizationSubtitle;

  /// No description provided for @startAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Start Analysis'**
  String get startAnalysis;
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
