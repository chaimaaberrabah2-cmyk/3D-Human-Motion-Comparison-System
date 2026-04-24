// ============================================================
// lib/features/authentication/presentation/pages/starting_page.dart
// ============================================================
// Page de bienvenue (Onboarding / Landing page).
//
// Premier écran potentiel pour un nouvel utilisateur (à configurer).
// Présente l'application Motion AI et offre des boutons clairs pour :
//   - Se connecter ("Log In") → navigue vers `/sign-in`
//   - S'inscrire ("Sign Up") → navigue vers `/sign-up`
// ============================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Landing / splash page. No business logic — pure presentation.
/// Tapping "Launch Analysis Engine" navigates to the Sign In route.
class StartingPage extends StatelessWidget {
  const StartingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 1. Background image ────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      AppColors.accentDark2,
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── 2. Dark overlay ────────────────────────────────────────────
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),

          // ── 3. Content ─────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 99.0,
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, AppColors.accentBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Text(
                      'MOTION AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2.0,
                        height: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Subtitle
                  Text(
                    "The world's most advanced 3D Human Motion Comparison\n"
                    "System. Analyze, compare, and perfect every movement with\n"
                    "deep learning precision.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textGray,
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // CTA button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBlue.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/sign-in'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Launch Analysis Engine',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Feature cards
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FeatureCard(
                        icon: Icons.flash_on_rounded,
                        title: 'Real-Time Analysis',
                        description:
                            'High-precision pose estimation using multi-view deep learning architecture.',
                      ),
                      const SizedBox(width: 60),
                      _FeatureCard(
                        icon: Icons.shield_outlined,
                        title: '3D Reconstruction',
                        description:
                            'Generate accurate 3D skeletal models from standard 2D video feeds.',
                      ),
                      const SizedBox(width: 60),
                      _FeatureCard(
                        icon: Icons.analytics_outlined,
                        title: 'Comparative Analytics',
                        description:
                            'Compare movements against professional benchmarks and targets.',
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private reusable card widget ──────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 180,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background.withValues(alpha: 0.9),
              AppColors.accentDark2.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.accentDark2.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentDark2.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.accentBlue, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 12,
                  height: 1.4,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
