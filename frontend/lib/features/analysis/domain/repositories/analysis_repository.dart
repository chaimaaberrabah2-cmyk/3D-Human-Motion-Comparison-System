// ============================================================
// lib/features/analysis/domain/repositories/analysis_repository.dart
// ============================================================
// Définit le CONTRAT (interface) pour les opérations d'analyse vidéo.
//
// Cette interface abstraite décrit CE QUI peut être fait dans la
// fonctionnalité d'analyse, sans définir le COMMENT.
//
// Méthodes :
//   analyzeVideos → Envoie 4 vidéos (une par angle de caméra) au backend
//                   et retourne l'identifiant de session (session_id) de l'analyse.
//
// Le paramètre `videos` est une map de type :
//   { 'angle_1': bytes_ou_chemin, 'angle_2': ..., 'angle_3': ..., 'angle_4': ... }
// ============================================================

/// Contrat abstrait pour les opérations d'analyse de la fonctionnalité Analysis.
abstract class AnalysisRepository {
  /// Envoie les 4 vidéos au backend pour analyse.
  /// Retourne le `session_id` généré par le serveur en cas de succès.
  /// [videos] : map nom_angle → données vidéo (bytes sur Web, chemin sur Mobile/Desktop).
  Future<String> analyzeVideos({
    required Map<String, dynamic> videos,
  });
}
