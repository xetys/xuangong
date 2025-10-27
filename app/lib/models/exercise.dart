class Exercise {
  final String id;
  final String name;
  final String description;
  final ExerciseType type;
  final int? durationSeconds;
  final int? repetitions;
  final int restAfterSeconds;
  final bool hasSides;
  final int? sideDurationSeconds;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.durationSeconds,
    this.repetitions,
    this.restAfterSeconds = 0,
    this.hasSides = false,
    this.sideDurationSeconds,
  });

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
