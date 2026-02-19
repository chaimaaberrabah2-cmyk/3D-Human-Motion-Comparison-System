class Exercise {
  final int id;
  final String name;
  final String category;
  final String imagePath;
  final String mode;
  final String description;
  final String difficulty;
  final List<String> instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.imagePath,
    required this.mode,
    required this.description,
    required this.difficulty,
    required this.instructions,
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
      description: 'The barbell back squat is a compound exercise that targets the quadriceps, hamstrings, and glutes. It is essential for building lower body strength and power.',
      difficulty: 'Intermediate',
      instructions: [
        'Stand with feet shoulder-width apart, toes slightly turned out.',
        'Place the barbell on your upper back, resting on your trapezius muscles.',
        'Brace your core and keep your chest up.',
        'Lower your hips back and down as if sitting in a chair.',
        'Go as deep as your mobility allows, ideally until thighs are parallel to the floor.',
        'Drive back up through your heels to the starting position.'
      ],
    ),
    Exercise(
      id: 2,
      name: 'Standard Push-up',
      category: 'Strength',
      imagePath: 'assets/exercises/pushup.png',
      mode: 'Strength Analysis Mode',
      description: 'A classic bodyweight exercise that builds upper body strength, focusing on the chest, shoulders, and triceps.',
      difficulty: 'Beginner',
      instructions: [
        'Start in a high plank position with hands slightly wider than shoulders.',
        'Keep your body in a straight line from head to heels.',
        'Lower your body until your chest nearly touches the floor.',
        'Push back up to the starting position, fully extending your arms.'
      ],
    ),
    Exercise(
      id: 3,
      name: 'Side Lateral Raise',
      category: 'Strength',
      imagePath: 'assets/exercises/lateral_raise.png',
      mode: 'Strength Analysis Mode',
      description: 'An isolation exercise for the shoulders, specifically targeting the lateral deltoids to build shoulder width.',
      difficulty: 'Beginner',
      instructions: [
        'Stand with dumbbells at your sides, palms facing inward.',
        'Keep a slight bend in your elbows.',
        'Raise your arms out to the sides until they are at shoulder height.',
        'Pause briefly at the top, then lower the weights under control.'
      ],
    ),
    Exercise(
      id: 4,
      name: 'Dumbbell Curl',
      category: 'Strength',
      imagePath: 'assets/exercises/curl.png',
      mode: 'Strength Analysis Mode',
      description: 'A fundamental biceps exercise that isolates the upper arm muscles for growth and strength.',
      difficulty: 'Beginner',
      instructions: [
        'Hold a dumbbell in each hand with palms facing forward.',
        'Keep your elbows close to your torso.',
        'Curl the weights up towards your shoulders.',
        'Squeeze your biceps at the top, then slowly lower the weights.'
      ],
    ),
    Exercise(
      id: 5,
      name: 'Leg Stretch',
      category: 'Mobility',
      imagePath: 'assets/exercises/stretch.png',
      mode: 'Mobility Analysis Mode',
      description: 'A simple stretching routine to improve flexibility in the hamstrings and calves.',
      difficulty: 'Beginner',
      instructions: [
        'Sit on the floor with one leg extended and the other bent.',
        'Reach forward towards the toes of the extended leg.',
        'Hold the stretch for 15-30 seconds without bouncing.',
        'Switch legs and repeat.'
      ],
    ),
    Exercise(
      id: 6,
      name: 'Shoulder Press',
      category: 'Strength',
      imagePath: 'assets/exercises/shoulder_press.png',
      mode: 'Strength Analysis Mode',
      description: 'A compound overhead pressing movement that builds mass and strength in the shoulders and triceps.',
      difficulty: 'Intermediate',
      instructions: [
        'Sit or stand with dumbbells at shoulder height, palms facing forward.',
        'Press the weights directly overhead until arms are fully extended.',
        'Lower the weights back down to ear level under control.'
      ],
    ),
  ];
}
