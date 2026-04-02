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
  /// Utilise 127.0.0.1 plutôt que localhost pour une meilleure compatibilité Flutter Web
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1/analysis';

  AnalysisRemoteDataSource({Dio? dio}) : this.dio = dio ?? Dio();

  /// Envoie les 4 vidéos au backend pour démarrer l'analyse.
  /// [videoData] : map 'angle_1' → bytes (Web) ou chemin (Native)
  /// Retourne le `session_id` créé par le serveur.
  Future<String> analyzeVideos({
    required Map<String, dynamic> videoData,
  }) async {
    final formDataMap = <String, dynamic>{};

    for (var entry in videoData.entries) {
      // Convertit 'angle_1' → 'angle1' pour correspondre aux paramètres FastAPI
      final key = entry.key.replaceAll('_', '');
      final value = entry.value;

      if (value == null) continue;

      if (kIsWeb && value is Uint8List) {
        // Plateforme Web : la vidéo est en mémoire sous forme de bytes
        formDataMap[key] = MultipartFile.fromBytes(
          value,
          filename: '$key.mp4',
        );
      } else if (value is String) {
        // Plateforme Native (macOS/iOS/Android) : la vidéo est un chemin de fichier
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
          // Affiche la progression de l'upload dans la console (en % )
          print('Progression upload : ${(sent / total * 100).toStringAsFixed(0)}%');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Retourne l'ID de session généré par le backend
        return response.data['session_id'] as String;
      } else {
        throw Exception('Échec du démarrage de l\'analyse : ${response.statusMessage}');
      }
    } catch (e) {
      if (e is DioException && e.response != null) {
        final detail = e.response?.data?['detail'] ?? e.message;
        throw Exception('Erreur serveur : $detail');
      }
      throw Exception('Erreur lors de l\'upload vidéo : $e');
    }
  }
}
