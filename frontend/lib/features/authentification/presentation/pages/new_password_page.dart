import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Placeholder — replace with the full implementation when available.
class NewPasswordPage extends StatelessWidget {
  const NewPasswordPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.password, color: AppColors.accentBlue, size: 64),
            const SizedBox(height: 24),
            const Text(
              'New Password',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please set your new password.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/success'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simulate Update Password'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/sign-in'),
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
      ),
    );
  }
}
