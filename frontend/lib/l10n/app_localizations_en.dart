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
  String get history => 'History';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get viewAllRecords => 'View All Records';

  @override
  String get totalSessions => 'Total Sessions';

  @override
  String get avgAccuracy => 'Avg. Accuracy';

  @override
  String get processingTime => 'Processing Time';

  @override
  String get activeCameras => 'Active Cameras';

  @override
  String get sessionId => 'Session ID';

  @override
  String get dateTime => 'Date & Time';

  @override
  String get deviceSource => 'Device Source';

  @override
  String get duration => 'Duration';

  @override
  String get score => 'SCORE';

  @override
  String get performancePreview => 'Preview';

  @override
  String get completedStatus => 'Completed';

  @override
  String get failedStatus => 'Failed';

  @override
  String get stable => 'Stable';

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
  String get addCalibrationData => 'ADD CALIBRATION DATA';

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

  @override
  String get addNewCamera => 'Add New Camera';

  @override
  String get deleteCameraTitle => 'Delete Camera?';

  @override
  String deleteCameraMessage(String cameraName) {
    return 'Are you sure you want to delete $cameraName? This action cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get minimumCamerasWarning => 'You must have at least 4 cameras';

  @override
  String get languageLabel => '(Language)';

  @override
  String get unsavedChangesTitle => 'Unsaved Changes';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. What would you like to do?';

  @override
  String get saveAndContinue => 'Save & Continue';

  @override
  String get discardAndContinue => 'Discard & Continue';

  @override
  String get cameraSource => 'Camera Source';

  @override
  String get calibrationFile => 'Calibration File';

  @override
  String get uploadCalibration => 'Upload Calibration';

  @override
  String get dragDropHint => 'or drag and drop your .bin or .json file here';

  @override
  String get statusCalibrated => 'Status: Calibrated';

  @override
  String get aiAlgorithm => 'AI Algorithm';

  @override
  String get blazePose => 'MediaPipe (BlazePose)';

  @override
  String get openPose => 'OpenPose';

  @override
  String get yolo => 'YOLO';

  @override
  String get pavllo => 'Pavllo';

  @override
  String get blazePoseDesc =>
      'Fast & lightweight. Best for real-time mobile use.';

  @override
  String get openPoseDesc => 'High accuracy. Resource heavy.';

  @override
  String get yoloDesc =>
      'Rapid object & pose detection. Balanced speed/accuracy.';

  @override
  String get pavlloDesc => 'Specialized 3D human pose lifting from 2D video.';

  @override
  String get startRecording => 'Start Recording';

  @override
  String get rec => 'REC';

  @override
  String get start => 'Start';

  @override
  String get newAnalysis => 'New Analysis';

  @override
  String get selectExercise => 'Select exercice';

  @override
  String get pleaseSelectExercise => 'Please select your reference exercice';

  @override
  String get userReconstruction => 'USER RECONSTRUCTION';

  @override
  String get analysisResultsTitle => 'Analysis Results';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get exportingPdfMessage => 'Exporting PDF... (Feature in development)';

  @override
  String get syncVideoStreams => 'Synchronizing video streams...';

  @override
  String get extractingKeypoints => 'Extracting 2D keypoints (BlazePose)...';

  @override
  String get fittingSmpl => 'Fitting SMPL-X body model...';

  @override
  String get optimizingMesh => 'Optimizing 3D mesh reconstruction...';

  @override
  String get generatingReports => 'Generating comparison reports...';

  @override
  String remainingTimeLabel(int time) {
    return 'Remaining time: ${time}s';
  }

  @override
  String get logAnalysisStarted => 'ANALYSIS STARTED';

  @override
  String get logSyncOk => 'SYCHRONIZING STREAMS - OK';

  @override
  String get logExtractionProgress => 'KEYPOINT EXTRACTION IN PROGRESS';

  @override
  String get logSmplActive => 'SMPL-X MESH FITTING ACTIVE';

  @override
  String analysisFeedback(String exerciseName) {
    return 'Comparing your movement with $exerciseName. Initial analysis shows 85% form accuracy. Focus on lowering your hips further during the eccentric phase.';
  }

  @override
  String get strengthAnalysisMode => 'Strength Analysis Mode';

  @override
  String get mobilityAnalysisMode => 'Mobility Analysis Mode';

  @override
  String get beginner => 'Beginner';

  @override
  String get intermediate => 'Intermediate';

  @override
  String get advanced => 'Advanced';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get instructionsLabel => 'Instructions';

  @override
  String get motionVisualization => '3D Motion Visualization';

  @override
  String get motionVisualizationSubtitle =>
      'Ideal motion comparison will appear here';

  @override
  String get startAnalysis => 'Start Analysis';
}
