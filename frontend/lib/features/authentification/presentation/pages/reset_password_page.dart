// ============================================================
// lib/features/authentification/presentation/pages/reset_password_page.dart
// ============================================================
// Page de vérification du code OTP (One Time Password).
//
// Affiche l'adresse email (reçue en argument) à laquelle le code
// a été envoyé. L'utilisateur saisit le code.
// Géré par `ResetPasswordController`. Navigue vers `/new-password`
// si le code est validé par le backend.
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/reset_password_controller.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late ResetPasswordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ResetPasswordController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await _controller.verifyCode(
      code: _codeController.text.trim(),
    );

    if (success && mounted) {
      final email = ModalRoute.of(context)?.settings.arguments as String? ?? 'user@motionai.com';
      Navigator.pushNamed(context, '/new-password', arguments: email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
          },
        ),
      ),
    );
  }

  // ── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 40, child: _buildBrandingPanel()),
        SizedBox(width: 600, child: _buildFormPanel(horizontalPadding: 60)),
      ],
    );
  }

  // ── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: _buildBrandingPanel(),
          ),
          _buildFormPanel(horizontalPadding: 24),
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

  // ── Form panel ────────────────────────────────────────────────────────────

  Widget _buildFormPanel({required double horizontalPadding}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
          child: Center(
            child: SizedBox(
              width: 430,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter Code',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Saisissez le code envoyé.\n(Test PFE : Veuillez taper le code 1234)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Code field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardStroke),
                      ),
                      child: TextFormField(
                        controller: _codeController,
                        style: const TextStyle(color: Colors.white),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Code is required';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Code',
                          hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5)),
                          prefixIcon: Icon(
                            Icons.lock_person_outlined,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          errorStyle: const TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                    ),

                    // Error message
                    Consumer<ResetPasswordController>(
                      builder: (_, ctrl, __) {
                        if (ctrl.status != ResetPasswordStatus.error) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            ctrl.errorMessage ?? 'An error occurred.',
                            style: const TextStyle(
                                color: Color(0xFFEF4444), fontSize: 13),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Reset Button
                    Consumer<ResetPasswordController>(
                      builder: (_, ctrl, __) => ElevatedButton(
                        onPressed: ctrl.isLoading ? null : _handleReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.accentBlue.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: ctrl.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Reset Password',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Back to Sign In
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.accentBlue.withValues(alpha: 0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, '/sign-in'),
                          child: const Text(
                            'Back to Sign In',
                            style: TextStyle(
                              color: AppColors.accentBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
