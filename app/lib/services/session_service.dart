import '../config/api_config.dart';
import '../models/session.dart';
import '../models/session_stats.dart';
import 'api_client.dart';

class SessionService {
  final ApiClient _apiClient = ApiClient();

  // Start a new session (creates session record)
  Future<PracticeSession> startSession(String programId) async {
    try {
      final response = await _apiClient.post(
        '${ApiConfig.apiBase}/sessions/start',
        {'program_id': programId},
      );

      final data = _apiClient.parseResponse(response);
      return PracticeSession.fromJson(data);
    } catch (e) {
      throw Exception('Failed to start session: ${e.toString()}');
    }
  }

  // Get a session by ID
  Future<SessionWithLogs> getSession(String sessionId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/sessions/$sessionId',
      );

      final data = _apiClient.parseResponse(response);
      return SessionWithLogs.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get session: ${e.toString()}');
    }
  }

  // List all sessions (with optional filters)
  Future<List<SessionWithLogs>> listSessions({
    String? programId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (programId != null) {
        queryParams['program_id'] = programId;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String().split('T')[0]; // YYYY-MM-DD format
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String().split('T')[0]; // YYYY-MM-DD format
      }

      final uri = Uri.parse('${ApiConfig.apiBase}/sessions')
          .replace(queryParameters: queryParams);

      final response = await _apiClient.get(uri.toString());
      final data = _apiClient.parseResponse(response);

      final sessions = data['sessions'] as List<dynamic>;
      return sessions.map((s) => SessionWithLogs.fromJson(s)).toList();
    } catch (e) {
      throw Exception('Failed to list sessions: ${e.toString()}');
    }
  }

  // Log exercise completion (for repetition-based exercises)
  Future<void> logExercise(
    String sessionId,
    String exerciseId, {
    int? repetitionsCompleted,
  }) async {
    try {
      await _apiClient.put(
        '${ApiConfig.apiBase}/sessions/$sessionId/exercise/$exerciseId',
        {
          if (repetitionsCompleted != null)
            'repetitions_completed': repetitionsCompleted,
        },
      );
    } catch (e) {
      throw Exception('Failed to log exercise: ${e.toString()}');
    }
  }

  // Complete a session
  Future<void> completeSession(
    String sessionId, {
    int? totalDurationSeconds,
    double? completionRate,
    String? notes,
    DateTime? completedAt,
  }) async {
    try {
      await _apiClient.put(
        '${ApiConfig.apiBase}/sessions/$sessionId/complete',
        {
          if (totalDurationSeconds != null) 'total_duration_seconds': totalDurationSeconds,
          if (completionRate != null) 'completion_rate': completionRate,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
          if (completedAt != null) 'completed_at': completedAt.toIso8601String(),
        },
      );
    } catch (e) {
      throw Exception('Failed to complete session: ${e.toString()}');
    }
  }

  // Get session statistics
  Future<SessionStats> getStats() async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/sessions/stats',
      );

      final data = _apiClient.parseResponse(response);
      return SessionStats.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get session stats: ${e.toString()}');
    }
  }

  // Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _apiClient.delete(
        '${ApiConfig.apiBase}/sessions/$sessionId',
      );
    } catch (e) {
      throw Exception('Failed to delete session: ${e.toString()}');
    }
  }
}
