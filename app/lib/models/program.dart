import 'exercise.dart';

class Program {
  final String id;
  final String name;
  final String description;
  final List<Exercise> exercises;
  final List<String> tags;

  Program({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
    this.tags = const [],
  });

  int get totalDurationMinutes {
    int totalSeconds = 0;
    for (var exercise in exercises) {
      if (exercise.durationSeconds != null) {
        totalSeconds += exercise.durationSeconds!;
      }
      if (exercise.hasSides && exercise.sideDurationSeconds != null) {
        totalSeconds += exercise.sideDurationSeconds!;
      }
      totalSeconds += exercise.restAfterSeconds;
    }
    return (totalSeconds / 60).ceil();
  }

  // Mock data for demonstration
  static Program getMockProgram() {
    return Program(
      id: '1',
      name: 'Morning Qi Gong',
      description: 'Gentle movements to awaken the body and cultivate internal energy. Perfect for starting your day with clarity and focus.',
      tags: ['qi-gong', 'morning', 'beginner'],
      exercises: [
        Exercise(
          id: '1',
          name: 'Standing Meditation (Zhan Zhuang)',
          description: 'Stand in Wu Ji posture with arms at sides, feet shoulder-width apart. Root into the earth, relax your shoulders, and breathe naturally.',
          type: ExerciseType.timed,
          durationSeconds: 180, // 3 minutes
          restAfterSeconds: 30,
        ),
        Exercise(
          id: '2',
          name: 'Cloud Hands (Yun Shou)',
          description: 'Flowing side-to-side movement coordinating arms and waist. Move slowly and continuously like clouds drifting across the sky.',
          type: ExerciseType.repetition,
          repetitions: 8,
          restAfterSeconds: 30,
          hasSides: true,
        ),
        Exercise(
          id: '3',
          name: 'Single Whip',
          description: 'Classic Tai Chi posture transitioning from center to side. Maintain a low, stable stance while extending your energy outward.',
          type: ExerciseType.combined,
          durationSeconds: 60,
          repetitions: 3,
          restAfterSeconds: 30,
          hasSides: true,
          sideDurationSeconds: 30,
        ),
        Exercise(
          id: '4',
          name: 'Silk Reeling (Chan Si Gong)',
          description: 'Spiral movements originating from the dan tian, flowing through the body like silk being unwound from a cocoon.',
          type: ExerciseType.timed,
          durationSeconds: 120,
          restAfterSeconds: 30,
        ),
        Exercise(
          id: '5',
          name: 'Closing Form',
          description: 'Gather and store the qi cultivated during practice. Return to center with gratitude.',
          type: ExerciseType.timed,
          durationSeconds: 60,
          restAfterSeconds: 0,
        ),
      ],
    );
  }
}
