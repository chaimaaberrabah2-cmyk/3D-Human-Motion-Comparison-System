import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class PersonalInfoSection extends StatelessWidget {
  const PersonalInfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Row(
          children: [
            SvgPicture.asset(
              'assets/icons/user.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.accentBlue,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.personalInformation,
              style: const TextStyle(
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
                label: l10n.user,
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
                label: l10n.changePassword,
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
            icon: SvgPicture.asset(
              'assets/icons/edit.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppColors.textGray,
                BlendMode.srcIn,
              ),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
