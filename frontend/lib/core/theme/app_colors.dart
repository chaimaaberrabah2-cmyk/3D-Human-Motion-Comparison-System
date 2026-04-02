// ============================================================
// lib/core/theme/app_colors.dart
// ============================================================
// Palette de couleurs centrale pour toute l'application.
//
// Toutes les couleurs sont définies ici comme constantes statiques
// afin que :
//   - Modifier une couleur ici la met à jour partout dans l'app.
//   - Il n'y a pas de valeurs hexadécimales "magiques" dispersées.
//
// Groupes de couleurs :
//   Arrière-plans : couleurs bleu marine profondes pour le mode sombre
//   Accents       : bleu principal pour les boutons, liens, éléments actifs
//   Cartes        : couleurs de remplissage et de contour des panneaux
//   Texte         : blanc pour les titres, gris pour le texte secondaire
//
// Le constructeur privé `AppColors._()` empêche l'instanciation —
// cette classe est utilisée uniquement comme espace de noms de constantes.
// ============================================================

import 'package:flutter/material.dart';

/// Constantes de couleurs immuables — source unique de vérité pour la palette.
class AppColors {
  // ── Arrière-plans ─────────────────────────────────────────
  /// Arrière-plan bleu marine principal utilisé sur tous les écrans en mode sombre.
  static const Color background = Color(0xFF020617);
  /// Couleur de séparation bleue subtile pour les bordures de la barre latérale (30% opacité).
  static const Color sidebarSeparator = Color(0x4D1E3A8A);

  // ── Accents ───────────────────────────────────────────────
  /// Bleu interactif principal — utilisé pour les boutons, liens et états sélectionnés.
  static const Color accentBlue = Color(0xFF52A2FF);
  /// Surface teintée plus sombre utilisée pour les arrière-plans superposés.
  static const Color accentDark1 = Color(0xFF0C1223);
  /// Teinte sombre légèrement plus claire pour les sections contrastées.
  static const Color accentDark2 = Color(0xFF0E214F);

  // ── Cartes ────────────────────────────────────────────────
  /// Couleur de fond pour les widgets carte/panneau.
  static const Color cardFill = Color(0xFF0C101B);
  /// Couleur de bordure/contour pour les cartes.
  static const Color cardStroke = Color(0xFF1C293D);

  // ── Texte ─────────────────────────────────────────────────
  /// Couleur de texte principale (titres, étiquettes).
  static const Color textWhite = Color(0xFFFFFFFF);
  /// Couleur de texte secondaire/atténuée (sous-titres, espaces réservés).
  static const Color textGray = Color(0xFF818182);

  // Empêche l'instanciation — utiliser comme AppColors.accentBlue
  AppColors._();
}
