import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

class AiProcessingSection extends StatefulWidget {
  const AiProcessingSection({Key? key}) : super(key: key);

  @override
  State<AiProcessingSection> createState() => _AiProcessingSectionState();
}

class _AiProcessingSectionState extends State<AiProcessingSection> {
  String selectedEngine = 'deep_learning'; // 'deep_learning' or 'legacy'

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Container
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.deepLearningBackend, // This matches the header "Deep Learning Backend" in screenshot
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aiEngineDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              
              // Deep Learning Backend Option
              _buildEngineCard(
                context,
                id: 'deep_learning',
                icon: Icons.memory,
                title: l10n.deepLearningBackend,
                description: l10n.deepLearningBackendDesc,
                isSelected: selectedEngine == 'deep_learning',
              ),
              
              const SizedBox(height: 16),
              
              // Legacy Pose2D Engine Option
              _buildEngineCard(
                context,
                id: 'legacy',
                icon: Icons.tune,
                title: l10n.legacyPose2DEngine,
                description: l10n.legacyPose2DDesc,
                isSelected: selectedEngine == 'legacy',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngineCard(
    BuildContext context, {
    required String id,
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => setState(() => selectedEngine = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                        ? (theme.brightness == Brightness.dark ? Colors.white : theme.primaryColor)
                        : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Selection Indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? theme.primaryColor : theme.dividerColor,
                  width: 2,
                ),
              ),
              child: isSelected ? Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ) : null,
            ),
          ],
        ),
      ),
    );
  }
}
