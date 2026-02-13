class Exercise {
  final int id;
  final String name;
  final String category;
  final String imagePath;
  final String mode;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    required this.mode,
  });
}

// Mock data for now
List<Exercise> getMockExercises() {
  return [
    Exercise(
      id: 1,
      name: 'Barbell Back Squat',
      category: 'Strength',
      imagePath: 'assets/exercises/squat.png',
      mode: 'Strength Analysis Mode',
    ),
    Exercise(
      id: 2,
      name: 'Standard Push-up',
      category: 'Strength',
      imagePath: 'assets/exercises/pushup.png',
      mode: 'Strength Analysis Mode',
    ),
    Exercise(
      id: 3,
      name: 'Side Lateral Raise',
      category: 'Strength',
      imagePath: 'assets/exercises/lateral_raise.png',
      mode: 'Strength Analysis Mode',
    ),
    Exercise(
      id: 4,
      name: 'Dumbbell Curl',
      category: 'Strength',
      imagePath: 'assets/exercises/curl.png',
      mode: 'Strength Analysis Mode',
    ),
    Exercise(
      id: 5,
      name: 'Leg Stretch',
      category: 'Mobility',
      imagePath: 'assets/exercises/stretch.png',
      mode: 'Mobility Analysis Mode',
    ),
    Exercise(
      id: 6,
      name: 'Shoulder Press',
      category: 'Strength',
      imagePath: 'assets/exercises/shoulder_press.png',
      mode: 'Strength Analysis Mode',
    ),
  ];
}
