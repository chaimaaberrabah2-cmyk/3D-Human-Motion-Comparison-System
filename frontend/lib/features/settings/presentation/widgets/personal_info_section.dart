import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class PersonalInfoSection extends StatelessWidget {
  const PersonalInfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
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
              colorFilter: ColorFilter.mode(
                theme.primaryColor,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.personalInformation,
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Info Cards Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: [
              // Username Field
              _buildInfoField(
                context,
                label: l10n.user,
                onEdit: () {},
              ),
              
              const SizedBox(height: 16),
              
              // Email Field
              _buildInfoField(
                context,
                label: 'user@motionai.com',
                onEdit: () {},
              ),
              
              const SizedBox(height: 16),
              
              // Change Password Button
              _buildInfoField(
                context,
                label: l10n.changePassword,
                onEdit: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoField(
    BuildContext context, {
    required String label,
    required VoidCallback onEdit,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: SvgPicture.asset(
              'assets/icons/edit.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                theme.textTheme.bodyMedium?.color ?? Colors.grey,
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
