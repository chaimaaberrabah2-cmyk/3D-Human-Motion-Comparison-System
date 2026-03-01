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
  String get history => 'Historique';

  @override
  String get recentActivity => 'Activité Récente';

  @override
  String get viewAllRecords => 'Tout Afficher';

  @override
  String get totalSessions => 'Total des Sessions';

  @override
  String get avgAccuracy => 'Précision Moyenne';

  @override
  String get processingTime => 'Temps de Traitement';

  @override
  String get activeCameras => 'Caméras Actives';

  @override
  String get sessionId => 'ID de Session';

  @override
  String get dateTime => 'Date et Heure';

  @override
  String get deviceSource => 'Source du Dispositif';

  @override
  String get duration => 'Durée';

  @override
  String get score => 'SCORE';

  @override
  String get performancePreview => 'Aperçu';

  @override
  String get completedStatus => 'Terminé';

  @override
  String get failedStatus => 'Échoué';

  @override
  String get stable => 'Stable';

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
  String get addCalibrationData => 'AJOUTER DES DONNÉES DE CALIBRATION';

  @override
  String get clickToUpload =>
      'Cliquez pour télécharger le fichier de calibration';

  @override
  String get uploadDesc => 'or drag and drop your .bin or .json file here';

  @override
  String get applyChanges => 'Appliquer les modifications';

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

  @override
  String get addNewCamera => 'Ajouter';

  @override
  String get deleteCameraTitle => 'Supprimer la Caméra?';

  @override
  String deleteCameraMessage(String cameraName) {
    return 'Êtes-vous sûr de vouloir supprimer $cameraName? Cette action ne peut pas être annulée.';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String get minimumCamerasWarning => 'Vous devez avoir au moins 4 caméras';

  @override
  String get languageLabel => '(Language)';

  @override
  String get unsavedChangesTitle => 'Modifications Non Enregistrées';

  @override
  String get unsavedChangesMessage =>
      'Vous avez des modifications non enregistrées. Que souhaitez-vous faire?';

  @override
  String get saveAndContinue => 'Enregistrer et Continuer';

  @override
  String get discardAndContinue => 'Annuler et Continuer';

  @override
  String get cameraSource => 'Source de la caméra';

  @override
  String get calibrationFile => 'Fichier de calibration';

  @override
  String get uploadCalibration => 'Télécharger ';

  @override
  String get dragDropHint =>
      'ou glissez-déposez votre fichier .bin ou .json ici';

  @override
  String get statusCalibrated => 'Statut: Calibré';

  @override
  String get aiAlgorithm => 'Algorithme IA';

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
      'Rapide et léger. Idéal pour mobile en temps réel.';

  @override
  String get openPoseDesc => 'Haute précision. Gourmand en ressources.';

  @override
  String get yoloDesc => 'Détection rapide d\'objets et de poses. Équilibré.';

  @override
  String get pavlloDesc =>
      'Lifting de pose 3D spécialisé à partir de vidéo 2D.';

  @override
  String get startRecording => 'Enregistrement';

  @override
  String get rec => 'ENR';

  @override
  String get start => 'Démarrer';

  @override
  String get newAnalysis => 'Nouvelle Analyse';

  @override
  String get selectExercise => 'Choisir l\'exercice';

  @override
  String get pleaseSelectExercise =>
      'Veuillez sélectionner votre exercice de référence';

  @override
  String get userReconstruction => 'RECONSTRUCTION UTILISATEUR';

  @override
  String get analysisResultsTitle => 'Résultats de l\'Analyse';

  @override
  String get exportPdf => 'Exporter en PDF';

  @override
  String get exportingPdfMessage =>
      'Exportation PDF... (Fonctionnalité en développement)';

  @override
  String get syncVideoStreams => 'Synchronisation des flux vidéo...';

  @override
  String get extractingKeypoints => 'Extraction des points clés (BlazePose)...';

  @override
  String get fittingSmpl => 'Ajustement du modèle corporel SMPL-X...';

  @override
  String get optimizingMesh => 'Optimisation de la reconstruction 3D...';

  @override
  String get generatingReports => 'Génération des rapports de comparaison...';

  @override
  String remainingTimeLabel(int time) {
    return 'Temps restant : ${time}s';
  }

  @override
  String get logAnalysisStarted => 'ANALYSE DÉMARRÉE';

  @override
  String get logSyncOk => 'SYNCHRONISATION DES FLUX - OK';

  @override
  String get logExtractionProgress => 'EXTRACTION DES POINTS CLÉS EN COURS';

  @override
  String get logSmplActive => 'AJUSTEMENT DU MAILLAGE SMPL-X ACTIF';

  @override
  String analysisFeedback(String exerciseName) {
    return 'Comparaison de votre mouvement avec $exerciseName. L\'analyse initiale montre une précision de forme de 85 %. Concentrez-vous sur l\'abaissement de vos hanches pendant la phase excentrique.';
  }

  @override
  String get strengthAnalysisMode => 'Mode d\'Analyse de Force';

  @override
  String get mobilityAnalysisMode => 'Mode d\'Analyse de Mobilité';

  @override
  String get beginner => 'Débutant';

  @override
  String get intermediate => 'Intermédiaire';

  @override
  String get advanced => 'Avancé';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get instructionsLabel => 'Instructions';

  @override
  String get motionVisualization => 'Visualisation du Mouvement 3D';

  @override
  String get motionVisualizationSubtitle =>
      'La comparaison du mouvement idéal apparaîtra ici';

  @override
  String get startAnalysis => 'Démarrer l\'Analyse';
}
