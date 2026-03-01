import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/exercise.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onPlayTapped;

  const ExerciseCard({
    Key? key,
    required this.exercise,
    required this.onPlayTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Ensure splash effect is contained
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPlayTapped, // Using the passed callback for the whole card
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise Image
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                  ),
                  child: Hero(
                    tag: 'exercise_${exercise.id}', // Hero tag for smooth transition
                    child: Image.asset(
                      exercise.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Placeholder when image not found
                        return Container(
                          color: theme.primaryColor.withOpacity(0.1),
                          child: Center(
                            child: Icon(
                              Icons.fitness_center,
                              size: 64,
                              color: theme.iconTheme.color?.withOpacity(0.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              // Exercise Info
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name, // Nom propre, don't change
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getLocalizedMode(context, exercise.mode),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    
                    // Difficulty Badge & Action Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getLocalizedCategory(context, exercise.category),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        
                        // Small Arrow Icon indicating navigation
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.iconTheme.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocalizedCategory(BuildContext context, String category) {
    // Note: We use the existing l10n package
    // You should import '../../../../l10n/app_localizations.dart' if not already there
    final l10n = AppLocalizations.of(context)!;
    switch (category.toLowerCase()) {
      case 'strength':
        return l10n.strength;
      case 'mobility':
        return l10n.mobility;
      case 'bodyweight':
        return l10n.bodyWeight;
      case 'rehab':
        return l10n.rehab;
      default:
        return category;
    }
  }

  String _getLocalizedMode(BuildContext context, String mode) {
    final l10n = AppLocalizations.of(context)!;
    if (mode.contains('Strength')) {
      return l10n.strengthAnalysisMode;
    } else if (mode.contains('Mobility')) {
      return l10n.mobilityAnalysisMode;
    }
    return mode;
  }
}
