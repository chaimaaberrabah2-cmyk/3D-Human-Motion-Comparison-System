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

  @override
  String get deepLearningBackend => 'Deep Learning Backend';

  @override
  String get status => 'Status';

  @override
  String get calibrated => 'Calibrated';

  @override
  String get processingModel => 'Processing Model';

  @override
  String get performanceMode => 'Performance Mode';

  @override
  String get computingDevice => 'Computing Device';

  @override
  String get highAccuracy => 'High Accuracy';

  @override
  String get balanced => 'Balanced';

  @override
  String get highSpeed => 'High Speed';

  @override
  String modifyCamera(String cameraName) {
    return 'Modify $cameraName';
  }

  @override
  String get updateDeviceSource =>
      'Update device source and calibration parameters';

  @override
  String get chooseCameraSource => '1. CHOOSE CAMERA SOURCE';

  @override
  String get addCalibrationData => '2. ADD CALIBRATION DATA';

  @override
  String get clickToUpload => 'Click to upload calibration file';

  @override
  String get uploadDesc => 'or drag and drop your .bin or .json file here';

  @override
  String get applyChanges => 'Apply Changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get aiEngineDescription =>
      'Select the AI engine for keypoint extraction and SMPL fitting.';

  @override
  String get legacyPose2DEngine => 'Lagacy Pose2D Engine';

  @override
  String get legacyPose2DDesc => 'Faster processing, reduced spatial accuracy.';

  @override
  String get deepLearningBackendDesc =>
      'Optimized for high-fidelity posture tracking.';

  @override
  String get newMultiViewAnalysis => 'New Multi-View Analysis';

  @override
  String get newAnalysisSubtitle =>
      'Upload synchronized video streams for 3D reconstruction and SMPL modeling';

  @override
  String get captureMethod => 'CAPTURE METHOD';

  @override
  String get uploadStreams => 'UPLOAD STREAMS';

  @override
  String get syncAndProcess => 'SYNC & PROCESS';

  @override
  String get uploadFiles => 'Upload Files';

  @override
  String get uploadFilesDesc =>
      'Upload existing synchronized video files from up to 4 camera angles.';

  @override
  String get liveMultiCam => 'Live Multi-Cam';

  @override
  String get liveMultiCamDesc =>
      'Stream directly from connected cameras for real-time analysis.';

  @override
  String get analysisInfoBanner =>
      'For best results, ensure all cameras share the same frame rate and are calibrated using the provided calibration pattern.';

  @override
  String get cameraAngleFront => 'Camera Angle 1 - Front';

  @override
  String get cameraAngleLeft => 'Camera angle 2 - Left';

  @override
  String get cameraAngleBack => 'Camera Angle 3 - Back';

  @override
  String get cameraAngleRight => 'Camera Angle 4 - Right';

  @override
  String get back => 'Back';
}
