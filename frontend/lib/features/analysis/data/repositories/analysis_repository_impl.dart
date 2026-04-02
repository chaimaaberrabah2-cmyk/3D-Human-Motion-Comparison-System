// ============================================================
// lib/features/analysis/data/repositories/analysis_repository_impl.dart
// ============================================================
// Implémentation concrète de `AnalysisRepository`.
//
// Cette classe fait le pont entre le domain (les cases d'utilisation)
// et la couche data (AnalysisRemoteDataSource qui appelle le backend FastAPI).
//
// Patron de conception :
//   NewAnalysisPage → (via un futur use case) → AnalysisRepositoryImpl
//                                             → AnalysisRemoteDataSource
//                                             → Backend FastAPI /analyze
// ============================================================

import '../datasources/analysis_remote_datasource.dart';
import '../../domain/repositories/analysis_repository.dart';

/// Implémentation concrète du repository d'analyse.
/// Délègue les appels réseau à [AnalysisRemoteDataSource].
class AnalysisRepositoryImpl implements AnalysisRepository {
  final AnalysisRemoteDataSource remoteDataSource;

  AnalysisRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String> analyzeVideos({
    required Map<String, dynamic> videos,
  }) async {
    try {
      // Délègue l'envoi des vidéos à la source de données distante
      return await remoteDataSource.analyzeVideos(videoData: videos);
    } catch (e) {
      // Relève l'exception — peut être transformée en erreur domaine si nécessaire
      rethrow;
    }
  }
}
