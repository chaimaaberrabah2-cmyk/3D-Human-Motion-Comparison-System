import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PersonalInfoSection extends StatelessWidget {
  const PersonalInfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            const Icon(
              Icons.person_outline,
              color: AppColors.accentBlue,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Personal Information',
              style: TextStyle(
                color: AppColors.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Info Cards Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E172B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1C293D)),
          ),
          child: Column(
            children: [
              // Username Field
              _buildInfoField(
                label: 'User',
                onEdit: () {},
              ),
              
              const SizedBox(height: 16),
              
              // Email Field
              _buildInfoField(
                label: 'user@motionai.com',
                onEdit: () {},
              ),
              
              const SizedBox(height: 16),
              
              // Change Password Button
              _buildInfoField(
                label: 'Change password',
                onEdit: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField({
    required String label,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C293D).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textWhite,
              fontSize: 14,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textGray,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
