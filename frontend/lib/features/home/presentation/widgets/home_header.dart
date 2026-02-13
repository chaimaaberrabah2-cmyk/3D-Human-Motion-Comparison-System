import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';

class HomeHeader extends StatelessWidget {
  final String username;
  final VoidCallback onStartAnalysis;

  const HomeHeader({
    Key? key,
    required this.username,
    required this.onStartAnalysis,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Welcome Text
          Text(
            'Welcome back, $username',
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // Start New Analysis Button
          ElevatedButton.icon(
            onPressed: onStartAnalysis,
            icon: SvgPicture.asset(
              'assets/icons/newanalysis.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.textWhite,
                BlendMode.srcIn,
              ),
            ),
            label: const Text('Start New Analysis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: AppColors.textWhite,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: const Color(0xFF1E3A8A).withOpacity(0.3),
                  width: 1,
                ),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
