class Exercise {
  final String id;
  final String programId;
  final String name;
  final String description;
  final int orderIndex;
  final ExerciseType type;
  final int? durationSeconds;
  final int? repetitions;
  final int restAfterSeconds;
  final bool hasSides;
  final int? sideDurationSeconds;
  final Map<String, dynamic>? metadata;

  Exercise({
    required this.id,
    required this.programId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.type,
    this.durationSeconds,
    this.repetitions,
    this.restAfterSeconds = 0,
    this.hasSides = false,
    this.sideDurationSeconds,
    this.metadata,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String? ?? '',
      programId: json['program_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      orderIndex: json['order_index'] as int? ?? 0,
      type: _exerciseTypeFromString(json['exercise_type'] as String? ?? 'timed'),
      durationSeconds: json['duration_seconds'] as int?,
      repetitions: json['repetitions'] as int?,
      restAfterSeconds: json['rest_after_seconds'] as int? ?? 0,
      hasSides: json['has_sides'] as bool? ?? false,
      sideDurationSeconds: json['side_duration_seconds'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'description': description,
      'order_index': orderIndex,
      'exercise_type': _exerciseTypeToString(type),
      'duration_seconds': durationSeconds,
      'repetitions': repetitions,
      'rest_after_seconds': restAfterSeconds,
      'has_sides': hasSides,
      'side_duration_seconds': sideDurationSeconds,
      'metadata': metadata,
    };
  }

  static ExerciseType _exerciseTypeFromString(String typeStr) {
    switch (typeStr) {
      case 'timed':
        return ExerciseType.timed;
      case 'repetition':
        return ExerciseType.repetition;
      case 'combined':
        return ExerciseType.combined;
      default:
        return ExerciseType.timed;
    }
  }

  static String _exerciseTypeToString(ExerciseType type) {
    switch (type) {
      case ExerciseType.timed:
        return 'timed';
      case ExerciseType.repetition:
        return 'repetition';
      case ExerciseType.combined:
        return 'combined';
    }
  }

  String get displayDuration {
    if (type == ExerciseType.timed && durationSeconds != null) {
      final minutes = durationSeconds! ~/ 60;
      final seconds = durationSeconds! % 60;
      if (minutes > 0) {
        return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
      }
      return '${seconds}s';
    } else if (type == ExerciseType.repetition && repetitions != null) {
      return '$repetitions reps';
    } else if (type == ExerciseType.combined) {
      return '$repetitions reps × ${_formatSeconds(durationSeconds ?? 0)}';
    }
    return '';
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return secs > 0 ? '${minutes}m ${secs}s' : '${minutes}m';
    }
    return '${secs}s';
  }
}

enum ExerciseType {
  timed,
  repetition,
  combined,
}
