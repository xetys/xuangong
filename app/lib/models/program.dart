import 'exercise.dart';

class Program {
  final String id;
  final String name;
  final String description;
  final List<Exercise> exercises;
  final List<String> tags;
  final bool isTemplate;
  final bool isPublic;
  final String? createdBy;
  final String? creatorName;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Program({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
    this.tags = const [],
    this.isTemplate = false,
    this.isPublic = false,
    this.createdBy,
    this.creatorName,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  factory Program.fromJson(Map<String, dynamic> json) {
    // Handle both direct program response and nested program+exercises response
    final programData = json.containsKey('program') ? json['program'] : json;
    final exercisesData = json.containsKey('exercises')
        ? json['exercises'] as List<dynamic>
        : programData['exercises'] as List<dynamic>? ?? [];

    return Program(
      id: programData['id'] as String,
      name: programData['name'] as String,
      description: programData['description'] as String? ?? '',
      tags: (programData['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      isTemplate: programData['is_template'] as bool? ?? false,
      isPublic: programData['is_public'] as bool? ?? false,
      createdBy: programData['created_by'] as String?,
      creatorName: programData['creator_name'] as String?,
      metadata: programData['metadata'] as Map<String, dynamic>?,
      createdAt: programData['created_at'] != null
          ? DateTime.parse(programData['created_at'] as String)
          : null,
      updatedAt: programData['updated_at'] != null
          ? DateTime.parse(programData['updated_at'] as String)
          : null,
      exercises: exercisesData.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tags': tags,
      'is_template': isTemplate,
      'is_public': isPublic,
      'metadata': metadata,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  Program copyAsPersonal() {
    return Program(
      id: '', // Will be assigned by backend
      name: name,
      description: description,
      exercises: exercises.map((e) => Exercise(
        id: '', // Will be assigned by backend
        programId: '', // Will be assigned by backend
        name: e.name,
        description: e.description,
        orderIndex: e.orderIndex,
        type: e.type,
        durationSeconds: e.durationSeconds,
        repetitions: e.repetitions,
        restAfterSeconds: e.restAfterSeconds,
        hasSides: e.hasSides,
        sideDurationSeconds: e.sideDurationSeconds,
        metadata: e.metadata,
      )).toList(),
      tags: tags,
      isTemplate: false,
      isPublic: false,
      metadata: metadata,
    );
  }

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
          programId: '1',
          name: 'Standing Meditation (Zhan Zhuang)',
          description: 'Stand in Wu Ji posture with arms at sides, feet shoulder-width apart. Root into the earth, relax your shoulders, and breathe naturally.',
          orderIndex: 0,
          type: ExerciseType.timed,
          durationSeconds: 180, // 3 minutes
          restAfterSeconds: 30,
        ),
        Exercise(
          id: '2',
          programId: '1',
          name: 'Cloud Hands (Yun Shou)',
          description: 'Flowing side-to-side movement coordinating arms and waist. Move slowly and continuously like clouds drifting across the sky.',
          orderIndex: 1,
          type: ExerciseType.repetition,
          repetitions: 8,
          restAfterSeconds: 30,
          hasSides: true,
        ),
        Exercise(
          id: '3',
          programId: '1',
          name: 'Single Whip',
          description: 'Classic Tai Chi posture transitioning from center to side. Maintain a low, stable stance while extending your energy outward.',
          orderIndex: 2,
          type: ExerciseType.combined,
          durationSeconds: 60,
          repetitions: 3,
          restAfterSeconds: 30,
          hasSides: true,
          sideDurationSeconds: 30,
        ),
        Exercise(
          id: '4',
          programId: '1',
          name: 'Silk Reeling (Chan Si Gong)',
          description: 'Spiral movements originating from the dan tian, flowing through the body like silk being unwound from a cocoon.',
          orderIndex: 3,
          type: ExerciseType.timed,
          durationSeconds: 120,
          restAfterSeconds: 30,
        ),
        Exercise(
          id: '5',
          programId: '1',
          name: 'Closing Form',
          description: 'Gather and store the qi cultivated during practice. Return to center with gratitude.',
          orderIndex: 4,
          type: ExerciseType.timed,
          durationSeconds: 60,
          restAfterSeconds: 0,
        ),
      ],
    );
  }
}
