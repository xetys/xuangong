class SessionStats {
  final int totalSessions;
  final int completedSessions;
  final int totalExercises;
  final Map<String, int> programCounts;
  final DateTime? lastSessionDate;
  final int currentStreak;

  SessionStats({
    required this.totalSessions,
    required this.completedSessions,
    required this.totalExercises,
    required this.programCounts,
    this.lastSessionDate,
    required this.currentStreak,
  });

  factory SessionStats.fromJson(Map<String, dynamic> json) {
    return SessionStats(
      totalSessions: json['total_sessions'] ?? 0,
      completedSessions: json['completed_sessions'] ?? 0,
      totalExercises: json['total_exercises'] ?? 0,
      programCounts: Map<String, int>.from(json['program_counts'] ?? {}),
      lastSessionDate: json['last_session_date'] != null
          ? DateTime.parse(json['last_session_date'])
          : null,
      currentStreak: json['current_streak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_sessions': totalSessions,
      'completed_sessions': completedSessions,
      'total_exercises': totalExercises,
      'program_counts': programCounts,
      'last_session_date': lastSessionDate?.toIso8601String(),
      'current_streak': currentStreak,
    };
  }
}
