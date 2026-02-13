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

  @override
  String get deepLearningBackend => 'Backend Deep Learning';

  @override
  String get status => 'Statut';

  @override
  String get calibrated => 'Calibré';

  @override
  String get processingModel => 'Modèle de Traitement';

  @override
  String get performanceMode => 'Mode de Performance';

  @override
  String get computingDevice => 'Appareil de Calcul';

  @override
  String get highAccuracy => 'Haute Précision';

  @override
  String get balanced => 'Équilibré';

  @override
  String get highSpeed => 'Haute Vitesse';

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
      'Sélectionnez le moteur IA pour l\'extraction des points clés et l\'ajustement SMPL.';

  @override
  String get legacyPose2DEngine => 'Moteur Legacy Pose2D';

  @override
  String get legacyPose2DDesc =>
      'Traitement plus rapide, précision spatiale réduite.';

  @override
  String get deepLearningBackendDesc =>
      'Optimisé pour le suivi des postures haute fidélité.';

  @override
  String get newMultiViewAnalysis => 'Nouvelle Analyse Multi-Vues';

  @override
  String get newAnalysisSubtitle =>
      'Téléchargez des flux vidéo synchronisés pour la reconstruction 3D et la modélisation SMPL';

  @override
  String get captureMethod => 'MÉTHODE DE CAPTURE';

  @override
  String get uploadStreams => 'TÉLÉCHARGER LES FLUX';

  @override
  String get syncAndProcess => 'SYNC & TRAITEMENT';

  @override
  String get uploadFiles => 'Télécharger des Fichiers';

  @override
  String get uploadFilesDesc =>
      'Téléchargez des fichiers vidéo synchronisés existants à partir de 4 angles de caméra maximum.';

  @override
  String get liveMultiCam => 'Multi-Caméra en Direct';

  @override
  String get liveMultiCamDesc =>
      'Diffusez directement à partir des caméras connectées pour une analyse en temps réel.';

  @override
  String get analysisInfoBanner =>
      'Pour de meilleurs résultats, assurez-vous que toutes les caméras partagent la même fréquence d\'images et sont calibrées à l\'aide du modèle de calibration fourni.';

  @override
  String get cameraAngleFront => 'Angle Caméra 1 - Face';

  @override
  String get cameraAngleLeft => 'Angle Caméra 2 - Gauche';

  @override
  String get cameraAngleBack => 'Angle Caméra 3 - Arrière';

  @override
  String get cameraAngleRight => 'Angle Caméra 4 - Droite';

  @override
  String get back => 'Retour';
}
