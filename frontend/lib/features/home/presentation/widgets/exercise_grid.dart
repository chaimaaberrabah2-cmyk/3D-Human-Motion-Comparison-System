import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/exercise_card.dart';

class ExerciseGrid extends StatelessWidget {
  final List<Exercise> exercises;
  final Function(Exercise) onExerciseTapped;

  const ExerciseGrid({
    Key? key,
    required this.exercises,
    required this.onExerciseTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > 700) {
          // Desktop & Web: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 0.85; // Slightly taller to fit content well in 3 columns
        } else {
          // Mobile: 1 column
          crossAxisCount = 1;
          childAspectRatio = 1.1; // Wider for single column mobile view
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            return ExerciseCard(
              exercise: exercise,
              onPlayTapped: () => onExerciseTapped(exercise),
            );
          },
        );
      },
    );
  }
}
