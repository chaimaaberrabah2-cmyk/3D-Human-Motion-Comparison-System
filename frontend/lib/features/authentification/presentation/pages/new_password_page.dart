import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/new_password_controller.dart';

class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late NewPasswordController _controller;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void initState() {
    super.initState();
    _controller = NewPasswordController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleReset(String email) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas !')),
      );
      return;
    }

    final success = await _controller.resetPassword(
      email,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/success');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get email from arguments
    final email = ModalRoute.of(context)?.settings.arguments as String? ?? 'user@motionai.com';

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 800;
            return isMobile
                ? _buildMobileLayout(email)
                : _buildDesktopLayout(email);
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(String email) {
    return Row(
      children: [
        Expanded(flex: 40, child: _buildBrandingPanel()),
        SizedBox(width: 600, child: _buildFormPanel(email, horizontalPadding: 60)),
      ],
    );
  }

  Widget _buildMobileLayout(String email) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 280,
            width: double.infinity,
            child: _buildBrandingPanel(),
          ),
          _buildFormPanel(email, horizontalPadding: 24),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel() {
    // Exact same branding as other pages
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
                      width: 65, height: 65,
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
                        Text('MOTION AI', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2)),
                        SizedBox(height: 2),
                        Text('3D Pose Analysis', style: TextStyle(fontSize: 15, color: AppColors.accentBlue, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                const Text('Precision in Every\nMovement.', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1)),
                const SizedBox(height: 7),
                Text('Reconstruct, analyze, and optimize human motion with\nenterprise-grade SMPL modeling.', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(String email, {required double horizontalPadding}) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
          child: Center(
            child: SizedBox(
              width: 430,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('New Password', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 12),
                    Text('Please set your new password.', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
                    const SizedBox(height: 40),

                    // Password
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'New Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure1,
                      onToggle: () => setState(() => _obscure1 = !_obscure1),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Password
                    _buildTextField(
                      controller: _confirmController,
                      hint: 'Confirm Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure2,
                      onToggle: () => setState(() => _obscure2 = !_obscure2),
                    ),

                    // Error msg
                    Consumer<NewPasswordController>(
                      builder: (_, ctrl, __) {
                        if (ctrl.status != NewPasswordStatus.error) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(ctrl.errorMessage ?? 'Error', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    Consumer<NewPasswordController>(
                      builder: (_, ctrl, __) => ElevatedButton(
                        onPressed: ctrl.isLoading ? null : () => _handleReset(email),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.accentBlue.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: ctrl.isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_ios_new, color: AppColors.accentBlue.withValues(alpha: 0.8), size: 14),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(context, '/sign-in'),
                          child: const Text('Back to Sign In', style: TextStyle(color: AppColors.accentBlue, fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
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
        style: const TextStyle(color: Colors.white),
        validator: (v) {
          if (v == null || v.length < 4) return 'Password too short';
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.5)),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          errorStyle: const TextStyle(color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
