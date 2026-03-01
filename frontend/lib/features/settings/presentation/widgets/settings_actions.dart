import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class SettingsActions extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  const SettingsActions({
    Key? key,
    required this.onSave,
    required this.onDiscard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Discard Button
        TextButton(
          onPressed: onDiscard,
          child: Text(
            l10n.discardChanges,
            style: const TextStyle(
              color: AppColors.textGray,
              fontSize: 14,
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Save Button
        ElevatedButton.icon(
          onPressed: onSave,
          icon: const Icon(Icons.save, size: 20),
          label: Text(l10n.saveSettings),
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
    );
  }
}
