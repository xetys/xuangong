class PracticeSession {
  final String id;
  final String userId;
  final String programId;
  final String? programName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;

  PracticeSession({
    required this.id,
    required this.userId,
    required this.programId,
    this.programName,
    required this.startedAt,
    this.completedAt,
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
      'notes': notes,
    };
  }
}

class ExerciseLog {
  final String? id;
  final String sessionId;
  final String exerciseId;
  final int? repetitionsCompleted;

  ExerciseLog({
    this.id,
    required this.sessionId,
    required this.exerciseId,
    this.repetitionsCompleted,
  });

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      id: json['id'],
      sessionId: json['session_id'],
      exerciseId: json['exercise_id'],
      repetitionsCompleted: json['repetitions_completed'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'repetitions_completed': repetitionsCompleted,
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
