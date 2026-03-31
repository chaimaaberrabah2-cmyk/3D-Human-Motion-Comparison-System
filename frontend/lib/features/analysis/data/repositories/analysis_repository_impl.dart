import '../datasources/analysis_remote_datasource.dart';
import '../../domain/repositories/analysis_repository.dart';

class AnalysisRepositoryImpl implements AnalysisRepository {
  final AnalysisRemoteDataSource remoteDataSource;

  AnalysisRepositoryImpl({required this.remoteDataSource});

  @override
  Future<String> analyzeVideos({
    required Map<String, dynamic> videos,
  }) async {
    try {
      return await remoteDataSource.analyzeVideos(videoData: videos);
    } catch (e) {
      // Re-throw or map to domain-specific failures if needed
      rethrow;
    }
  }
}
