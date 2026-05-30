// ============================================================
// lib/features/analysis/data/datasources/analysis_remote_datasource.dart
// ============================================================
// Source de données distante pour la fonctionnalité d'analyse.
//
// C'est cette classe qui effectue DIRECTEMENT l'appel HTTP vers le
// backend FastAPI. Elle utilise la bibliothèque `Dio` pour :
//   - Construire un FormData multipart avec les 4 vidéos
//   - Envoyer la requête POST vers /api/v1/analysis/analyze
//   - Suivre la progression de l'upload
//   - Retourner le `session_id` créé par le serveur
//
// Compatibilité multi-plateforme :
//   - Web   : les vidéos sont des `Uint8List` (bytes en mémoire)
//   - Native : les vidéos sont des chemins de fichier `String`
//
// URL de base : http://127.0.0.1:8000/api/v1/analysis
// (le serveur FastAPI doit être démarré avec `uvicorn app.main:app --reload`)
// ============================================================

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../home/domain/entities/exercise.dart';

/// Gère les appels HTTP vers le backend d'analyse vidéo.
class AnalysisRemoteDataSource {
  final Dio dio;

  /// URL de base de l'API backend
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/analysis';
  static const String sessionsUrl = 'http://127.0.0.1:8000/api/v1/sessions';
  static const String backendBase = 'http://127.0.0.1:8000';

  AnalysisRemoteDataSource({Dio? dio}) : this.dio = dio ?? Dio();

  /// Envoie les 4 vidéos au backend pour démarrer l'analyse.
  Future<String> analyzeVideos({
    required Map<String, dynamic> videoData,
    required String exercise,
    int? establishmentId,
    int? userId,
  }) async {
    final formDataMap = <String, dynamic>{};

    for (var entry in videoData.entries) {
      final key = entry.key.replaceAll('_', '');
      final value = entry.value;

      if (value == null) continue;

      if (kIsWeb && value is Uint8List) {
        formDataMap[key] = MultipartFile.fromBytes(value, filename: '$key.mp4');
      } else if (value is String) {
        formDataMap[key] = await MultipartFile.fromFile(value, filename: '$key.mp4');
      }
    }

    final formData = FormData.fromMap(formDataMap);

    try {
      final response = await dio.post(
        '$baseUrl/analyze',
        data: formData,
        queryParameters: {
          'exercise': exercise,
          if (establishmentId != null) 'establishment_id': establishmentId,
          if (userId != null) 'user_id': userId,
        },
        onSendProgress: (sent, total) {
          print('Upload: ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );


      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['session_id'] as String;
      } else {
        throw Exception('Analyse failed: ${response.statusMessage}');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final detail = e.response?.data?['detail'] ?? e.message;
        throw Exception('Server error: $detail');
      }
      throw Exception('Upload error: $e');
    }
  }

  /// Polls the session pipeline status from the backend.
  /// Returns a map with: progress_percent, is_complete, has_smplx_viewer, phases.
  Future<Map<String, dynamic>> fetchSessionStatus(String sessionId) async {
    try {
      final response = await dio.get('$sessionsUrl/$sessionId/status');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      throw Exception('Status fetch failed: ${response.statusCode}');
    } catch (e) {
      throw Exception('Status fetch error: $e');
    }
  }

  /// Returns the URL of the Three.js SMPL-X viewer for a session or movement reference.
  /// [embed] hides orientation calibration panels in the WebView (Flutter app).
  String getViewerUrl(String sessionId, {bool embed = true}) {
    final String path;
    if (sessionId.contains('-') || sessionId.length > 20) {
      path = '$sessionsUrl/$sessionId/viewer';
    } else {
      path = '$backendBase/api/v1/movements/$sessionId/viewer';
    }
    if (!embed) return path;
    return '$path?embed=1';
  }

  /// Fetches performance history for a user from the DB.
  Future<List<Map<String, dynamic>>> fetchHistory(int userId) async {
    try {
      final response = await dio.get(
        '$backendBase/api/v1/performances/',
        queryParameters: {'user_id': userId},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (e) {
      print('Error fetching history: $e');
    }
    return [];
  }

  /// Fetches time-series progress for a user (optionally filtered by exercise).
  Future<List<Map<String, dynamic>>> fetchProgress(int userId, {String? exercise}) async {
    try {
      final params = <String, dynamic>{'user_id': userId};
      if (exercise != null) params['exercise'] = exercise;
      final response = await dio.get(
        '$backendBase/api/v1/performances/progress',
        queryParameters: params,
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(
          (response.data as List).map((e) => Map<String, dynamic>.from(e)),
        );
      }
    } catch (e) {
      print('Error fetching progress: $e');
    }
    return [];
  }

  /// Fetches establishment-level stats (admin dashboard).
  Future<Map<String, dynamic>?> fetchEstablishmentStats(int establishmentId) async {
    try {
      final response = await dio.get(
        '$backendBase/api/v1/performances/establishment/$establishmentId/stats',
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      print('Error fetching establishment stats: $e');
    }
    return null;
  }

  /// Fetches movements from PostgreSQL database. Falls back to mock data if empty or offline.
  Future<List<Exercise>> fetchMovements() async {
    try {
      final response = await dio.get('$backendBase/api/v1/movements/');
      if (response.statusCode == 200) {
        final list = response.data as List;
        if (list.isEmpty) return getMockExercises();
        
        return list.map((item) {
          final id = item['movement_id'] as int? ?? 0;
          final name = item['name'] as String? ?? '';
          final category = item['category'] as String? ?? 'Strength';
          final desc = item['description'] as String? ?? '';
          final diff = item['difficulty'] as String? ?? 'Intermediate';
          final inst = List<String>.from(item['instructions'] ?? []);
          final thumb = item['thumbnail_path'] as String? ?? '';
          
          return Exercise(
            id: id,
            name: name,
            category: category,
            imagePath: thumb.isNotEmpty ? thumb : 'assets/exercises/squat.png',
            mode: '${category} Analysis Mode',
            description: desc,
            difficulty: diff,
            instructions: inst,
          );
        }).toList();
      }
      throw Exception('Failed to load movements: ${response.statusCode}');
    } catch (e) {
      print('Error fetching movements from database: $e');
      return getMockExercises(); // Graceful fallback
    }
  }
}
