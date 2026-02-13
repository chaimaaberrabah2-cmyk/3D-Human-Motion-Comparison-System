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
    final theme = Theme.of(context);
    final iconColor = isSelected 
        ? theme.primaryColor 
        : (theme.textTheme.bodyMedium?.color ?? Colors.grey);
        
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.primaryColor.withOpacity(0.1) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            iconPath.endsWith('.svg') 
                ? SvgPicture.asset(
                    iconPath,
                    width: 20,
                    height: 20,
                    // Only apply color filter if enabled
                    colorFilter: applyColorFilter
                        ? ColorFilter.mode(
                            iconColor,
                            BlendMode.srcIn,
                          )
                        : null,
                  )
                : Image.asset(
                    iconPath,
                    width: 20,
                    height: 20,
                    // For PNGs, we typically don't apply a color filter unless requested
                    color: applyColorFilter ? iconColor : null,
                  ),
            
            const SizedBox(width: 12),
            
            // Label
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected 
                    ? theme.primaryColor 
                    : theme.textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
