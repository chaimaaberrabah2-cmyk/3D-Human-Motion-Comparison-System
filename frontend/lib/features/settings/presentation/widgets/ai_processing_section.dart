import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';

class AiProcessingSection extends StatelessWidget {
  final String selectedEngine;
  final String selectedAlgorithm;
  final ValueChanged<String> onEngineChanged;
  final ValueChanged<String> onAlgorithmChanged;

  const AiProcessingSection({
    Key? key,
    required this.selectedEngine,
    required this.selectedAlgorithm,
    required this.onEngineChanged,
    required this.onAlgorithmChanged,
  }) : super(key: key);

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
                l10n.deepLearningBackend,
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
              const SizedBox(height: 12),
              // Legacy Pose2D Engine Option
              _buildEngineCard(
                context,
                id: 'legacy',
                icon: Icons.tune,
                title: l10n.legacyPose2DEngine,
                description: l10n.legacyPose2DDesc,
                isSelected: selectedEngine == 'legacy',
              ),

              // AI Algorithm Selection (Always visible)
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                l10n.aiAlgorithm,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Algorithm List
              _buildAlgorithmCard(context, 'blaze_pose', l10n.blazePose, l10n.blazePoseDesc),
              const SizedBox(height: 12),
              _buildAlgorithmCard(context, 'open_pose', l10n.openPose, l10n.openPoseDesc),
              const SizedBox(height: 12),
              _buildAlgorithmCard(context, 'yolo', l10n.yolo, l10n.yoloDesc),
              const SizedBox(height: 12),
              _buildAlgorithmCard(context, 'pavllo', l10n.pavllo, l10n.pavlloDesc),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlgorithmCard(BuildContext context, String id, String title, String description) {
    final theme = Theme.of(context);
    final isSelected = selectedAlgorithm == id;

    return GestureDetector(
      onTap: () => onAlgorithmChanged(id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.05) : theme.scaffoldBackgroundColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Radio Button style indicator
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
      onTap: () => onEngineChanged(id),
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
