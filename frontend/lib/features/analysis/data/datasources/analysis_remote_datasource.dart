import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AnalysisRemoteDataSource {
  final Dio dio;

  // Base URL for the backend API
  // Using 127.0.0.1 instead of localhost for better Flutter Web compatibility
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/analysis';

  AnalysisRemoteDataSource({Dio? dio}) : this.dio = dio ?? Dio();

  Future<String> analyzeVideos({
    required Map<String, dynamic> videoData, // angle_1 -> bytes or path
  }) async {
    final formDataMap = <String, dynamic>{};

    for (var entry in videoData.entries) {
      // Map 'angle_1' to 'angle1' to match backend FastAPI parameters
      final key = entry.key.replaceAll('_', '');
      final value = entry.value;

      if (value == null) continue;

      if (kIsWeb && value is Uint8List) {
        // Handle Web Multipart
        formDataMap[key] = MultipartFile.fromBytes(
          value,
          filename: '$key.mp4',
        );
      } else if (value is String) {
        // Handle Native Multipart
        formDataMap[key] = await MultipartFile.fromFile(
          value,
          filename: '$key.mp4',
        );
      }
    }

    final formData = FormData.fromMap(formDataMap);

    try {
      final response = await dio.post(
        '$baseUrl/analyze',
        data: formData,
        onSendProgress: (sent, total) {
          // Progress can be handled here if needed
          print('Upload progress: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['session_id'] as String;
      } else {
        throw Exception('Failed to start analysis: ${response.statusMessage}');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final detail = e.response?.data?['detail'] ?? e.message;
        throw Exception('Server Error: $detail');
      }
      throw Exception('Error during video upload: $e');
    }
  }
}
