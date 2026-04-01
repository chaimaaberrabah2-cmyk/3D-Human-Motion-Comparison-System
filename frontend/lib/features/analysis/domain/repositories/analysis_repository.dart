abstract class AnalysisRepository {
  Future<String> analyzeVideos({
    required Map<String, dynamic> videos, // Map of name -> bytes or path
  });
}
