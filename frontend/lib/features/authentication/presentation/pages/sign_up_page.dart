// ============================================================
// lib/features/authentication/presentation/pages/sign_up_page.dart
// ============================================================
// Page d'inscription pour créer un nouveau compte.
//
// Collecte le nom, l'email et le mot de passe de l'utilisateur.
// L'état est géré par `SignUpController`.
//
// Une fois l'inscription réussie, l'utilisateur est redirigé vers
// la page de confirmation (`/success`).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/sign_up_controller.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _establishmentCodeController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  DateTime? _selectedDob;
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late SignUpController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignUpController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _establishmentCodeController.dispose();
    _dobController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.accentBlue,
              onPrimary: Colors.white,
              surface: AppColors.cardFill,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppColors.background,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDob) {
      setState(() {
        _selectedDob = picked;
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final success = await _controller.signUp(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      establishmentCode: _establishmentCodeController.text.trim(),
    );

    if (success && mounted) {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role') ?? 'user';
      
      if (role == 'super_admin') {
        Navigator.pushReplacementNamed(context, '/super-admin');
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin');
      } else {
        if (_selectedDob != null) {
          final age = DateTime.now().year - _selectedDob!.year;
          await prefs.setString('user_age', age.toString());
        }
        Navigator.pushReplacementNamed(context, '/');
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Hide keyboard
    FocusScope.of(context).unfocus();

    final success = await _controller.signInWithGoogle();

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/');
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

  // ── Desktop: 2-column layout ──────────────────────────────────────────────

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(child: _buildBrandingPanel()),
        Expanded(child: _buildFormPanel(horizontalPadding: 60)),
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
            padding: const EdgeInsets.all(40),
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
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: 40),
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
                      'Create Account',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Join the next generation.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Name field
                    _buildTextField(
                      controller: _nameController,
                      hint: 'Name',
                      prefixIcon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Email field
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Email',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Establishment Code field
                    _buildTextField(
                      controller: _establishmentCodeController,
                      hint: 'Code Établissement / Clinic Code',
                      prefixIcon: Icons.business_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Establishment Code is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date of Birth field
                    GestureDetector(
                      onTap: () => _selectDateOfBirth(context),
                      child: AbsorbPointer(
                        child: _buildTextField(
                          controller: _dobController,
                          hint: 'Date of Birth (DD/MM/YYYY)',
                          prefixIcon: Icons.calendar_today_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Date of Birth is required';
                            }
                            return null;
                          },
                        ),
                      ),
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
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 4) return 'Minimum 4 characters';
                        return null;
                      },
                    ),

                    // Error message
                    Consumer<SignUpController>(
                      builder: (_, ctrl, __) {
                        if (ctrl.status != SignUpStatus.error) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            ctrl.errorMessage ?? 'An error occurred.',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Sign Up button
                    Consumer<SignUpController>(
                      builder: (_, ctrl, __) => ElevatedButton(
                        onPressed: ctrl.isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.accentBlue.withValues(alpha: 0.6),
                          padding:
                              const EdgeInsets.symmetric(vertical: 18),
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
                                'Sign Up',
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
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
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
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Google sign up
                    Center(
                      child: SizedBox(
                        width: 250,
                        child: Consumer<SignUpController>(
                          builder: (_, ctrl, __) => OutlinedButton.icon(
                            onPressed: ctrl.isLoading ? null : _handleGoogleSignIn,
                            icon: const Icon(Icons.g_mobiledata, size: 28),
                            label: const Text('Google'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Log in link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, '/sign-in'),
                          child: const Text(
                            'Log In',
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
          prefixIcon: Icon(prefixIcon,
              color: Colors.white.withValues(alpha: 0.5)),
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
