// ============================================================
// lib/features/authentication/presentation/pages/sign_in_page.dart
// ============================================================
// Page de connexion de l'application.
//
// Permet à un utilisateur existant de s'authentifier avec son email
// et son mot de passe.
// L'état et la logique métier sont gérés par `SignInController`.
//
// Fonctionnalités :
//   - Validation basique du formulaire (champs non vides)
//   - Affichage d'un indicateur de chargement pendant la requête
//   - Redirection vers le MainLayout (`/`) en cas de succès
//   - Liens vers l'inscription et la récupération de mot de passe
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/sign_in_controller.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({Key? key}) : super(key: key);

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late SignInController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignInController();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final savedPassword = prefs.getString('saved_password');
    if (savedEmail != null && savedPassword != null) {
      if (mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final success = await _controller.signIn(
      email: email,
      password: password,
    );

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_email', email);
        await prefs.setString('saved_password', password);
      } else {
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }

      // ROLE-BASED NAVIGATION
      final role = prefs.getString('user_role') ?? 'user';
      if (role == 'super_admin') {
        Navigator.pushReplacementNamed(context, '/super-admin');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final success = await _controller.signInWithGoogle();
    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? 'user';
      if (role == 'super_admin') {
        Navigator.pushReplacementNamed(context, '/super-admin');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        Navigator.pushReplacementNamed(context, '/');
      }
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
            if (isMobile) {
              return _buildMobileLayout();
            }
            return _buildDesktopLayout();
          },
        ),
      ),
    );
  }

  // ── Desktop: 2-column layout ──────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left branding panel
        Expanded(
          child: _buildBrandingPanel(),
        ),
        // Right form panel
        Expanded(
          child: _buildFormPanel(horizontalPadding: 60),
        ),
      ],
    );
  }

  // ── Mobile: single scrollable column ─────────────────────────────────────

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildFormPanel(horizontalPadding: 24),
        ],
      ),
    );
  }

  // ── Branding panel (left / top) ───────────────────────────────────────────

  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          FittedBox(
            fit: BoxFit.cover,
            alignment: const Alignment(-1.8, 0),
            child: Image.asset('assets/images/SignUp.png'),
          ),
          // Dark overlay
          Container(color: Colors.black.withValues(alpha: 0.45)),
          // Text content
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo row
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
                const SizedBox(height: 8),
                Text(
                  'Reconstruct, analyze, and optimize human motion\nwith enterprise-grade SMPL modeling.',
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

  // ── Form panel (right / bottom) ───────────────────────────────────────────

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
                    // Heading
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your credentials to access your motion dashboard.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Email field
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      prefixIcon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password is required';
                        if (v.length < 4) return 'Minimum 4 characters';
                        return null;
                      },
                    ),

                    // Error message
                    Consumer<SignInController>(
                      builder: (_, ctrl, __) {
                        if (ctrl.status != SignInStatus.error)
                          return const SizedBox.shrink();
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

                    // Stay connected & Forgot password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Theme(
                                data: Theme.of(context).copyWith(
                                  unselectedWidgetColor: Colors.white.withValues(alpha: 0.5),
                                ),
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.accentBlue,
                                  checkColor: Colors.white,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const Flexible(
                                child: Text(
                                  'Stay connected',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/forgot-password'),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.accentBlue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Sign in button
                    Consumer<SignInController>(
                      builder: (_, ctrl, __) => ElevatedButton(
                        onPressed: ctrl.isLoading ? null : _handleSignIn,
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
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or continue with',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Google sign-in
                    Center(
                      child: SizedBox(
                        width: 250,
                        child: Consumer<SignInController>(
                          builder: (_, ctrl, __) => OutlinedButton.icon(
                            onPressed: ctrl.isLoading ? null : _handleGoogleSignIn,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/sign-up'),
                          child: const Text(
                            'Sign Up',
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

  // ── Reusable text field ───────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData prefixIcon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardStroke),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(
            prefixIcon,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
