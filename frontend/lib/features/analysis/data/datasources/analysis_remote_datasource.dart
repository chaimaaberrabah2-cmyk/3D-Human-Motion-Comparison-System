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

  /// Returns the URL of the Three.js SMPL-X viewer for a session.
  String getViewerUrl(String sessionId) {
    return '$sessionsUrl/$sessionId/viewer';
  }
}
