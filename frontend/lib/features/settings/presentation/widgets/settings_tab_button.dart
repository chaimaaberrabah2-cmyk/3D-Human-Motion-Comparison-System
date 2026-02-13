import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsTabButton extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool applyColorFilter; // New parameter

  const SettingsTabButton({
    Key? key,
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.applyColorFilter = true, // Default to true
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Check file extension to determine rendering widget
              iconPath.endsWith('.svg')
                  ? SvgPicture.asset(
                      iconPath,
                      width: 20,
                      height: 20,
                      // Only apply color filter if enabled
                      colorFilter: applyColorFilter
                          ? ColorFilter.mode(
                              isSelected ? AppColors.accentBlue : AppColors.textGray,
                              BlendMode.srcIn,
                            )
                          : null,
                    )
                  : Image.asset(
                      iconPath,
                      width: 20,
                      height: 20,
                      // For PNGs, we typically don't apply a color filter unless requested
                      // If applyColorFilter is true, we tint it. If false, we show original.
                      color: applyColorFilter 
                          ? (isSelected ? AppColors.accentBlue : AppColors.textGray)
                          : null,
                    ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentBlue : AppColors.textGray,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
