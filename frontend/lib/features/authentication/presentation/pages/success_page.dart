// ============================================================
// lib/features/authentication/presentation/pages/success_page.dart
// ============================================================
// Page de confirmation générique.
//
// Affichée après le succès de certaines opérations (comme la
// création d'un compte ou la réinitialisation d'un mot de passe).
// Informe l'utilisateur que l'action a réussi et propose un bouton
// pour retourner à la page de connexion (`/sign-in`).
// ============================================================

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;
          return isMobile
              ? _buildMobileLayout(context)
              : _buildDesktopLayout(context);
        },
      ),
    );
  }

  // ── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 40, child: _buildBrandingPanel()),
        SizedBox(
            width: 600, child: _buildFormPanel(context, horizontalPadding: 60)),
      ],
    );
  }

  // ── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: _buildBrandingPanel(),
          ),
          _buildFormPanel(context, horizontalPadding: 24),
        ],
      ),
    );
  }

  // ── Branding panel ────────────────────────────────────────────────────────

  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            alignment: const Alignment(-1.8, 0),
            child: Image.asset('assets/images/SignUp.png'),
          ),
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 300, 80, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logo.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MOTION AI',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '3D Pose Analysis',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.accentBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text(
                  'Precision in Every\nMovement.',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Reconstruct, analyze, and optimize human motion with\nenterprise-grade SMPL modeling.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Success Form panel ────────────────────────────────────────────────────

  Widget _buildFormPanel(BuildContext context,
      {required double horizontalPadding}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
          child: Center(
            child: SizedBox(
              width: 430,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'All done',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'successfully created your account',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Success Icon - using project's style
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.5),
                          width: 4,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_rounded,
                          color: Color(0xFF4ADE80),
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),

                  // Back to Sign In button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/sign-in', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Back to Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
