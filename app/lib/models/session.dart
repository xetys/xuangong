class PracticeSession {
  final String id;
  final String userId;
  final String programId;
  final String? programName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? totalDurationSeconds;
  final double? completionRate;
  final String? notes;

  PracticeSession({
    required this.id,
    required this.userId,
    required this.programId,
    this.programName,
    required this.startedAt,
    this.completedAt,
    this.totalDurationSeconds,
    this.completionRate,
    this.notes,
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      id: json['id'],
      userId: json['user_id'],
      programId: json['program_id'],
      programName: json['program_name'],
      startedAt: DateTime.parse(json['started_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      totalDurationSeconds: json['total_duration_seconds'],
      completionRate: json['completion_rate']?.toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'program_id': programId,
      'program_name': programName,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'total_duration_seconds': totalDurationSeconds,
      'completion_rate': completionRate,
      'notes': notes,
    };
  }
}

class ExerciseLog {
  final String? id;
  final String sessionId;
  final String? exerciseId;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? plannedDurationSeconds;
  final int? actualDurationSeconds;
  final int? repetitionsPlanned;
  final int? repetitionsCompleted;
  final bool skipped;
  final String? notes;

  ExerciseLog({
    this.id,
    required this.sessionId,
    this.exerciseId,
    this.startedAt,
    this.completedAt,
    this.plannedDurationSeconds,
    this.actualDurationSeconds,
    this.repetitionsPlanned,
    this.repetitionsCompleted,
    this.skipped = false,
    this.notes,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      id: json['id'],
      sessionId: json['session_id'],
      exerciseId: json['exercise_id'],
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      plannedDurationSeconds: json['planned_duration_seconds'],
      actualDurationSeconds: json['actual_duration_seconds'],
      repetitionsPlanned: json['repetitions_planned'],
      repetitionsCompleted: json['repetitions_completed'],
      skipped: json['skipped'] ?? false,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'planned_duration_seconds': plannedDurationSeconds,
      'actual_duration_seconds': actualDurationSeconds,
      'repetitions_planned': repetitionsPlanned,
      'repetitions_completed': repetitionsCompleted,
      'skipped': skipped,
      'notes': notes,
    };
  }
}

class SessionWithLogs {
  final PracticeSession session;
  final List<ExerciseLog> exerciseLogs;

  SessionWithLogs({
    required this.session,
    required this.exerciseLogs,
  });

  factory SessionWithLogs.fromJson(Map<String, dynamic> json) {
    return SessionWithLogs(
      session: PracticeSession.fromJson(json['session']),
      exerciseLogs: (json['exercise_logs'] as List<dynamic>?)
              ?.map((log) => ExerciseLog.fromJson(log))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session': session.toJson(),
      'exercise_logs': exerciseLogs.map((log) => log.toJson()).toList(),
    };
  }
}
