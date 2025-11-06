import '../models/submission.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class SubmissionService {
  final ApiClient _apiClient = ApiClient();

  // Create new submission for a program
  Future<Submission> createSubmission(String programId, String title) async {
    try {
      final response = await _apiClient.post(
        '${ApiConfig.apiBase}/programs/$programId/submissions',
        {'title': title},
      );
      final data = _apiClient.parseResponse(response);

      return Submission.fromJson(data['submission'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create submission: $e');
    }
  }

  // List submissions with optional filters
  Future<List<SubmissionListItem>> listSubmissions({
    String? programId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String>[];
      if (programId != null) {
        queryParams.add('program_id=$programId');
      }
      queryParams.add('limit=$limit');
      queryParams.add('offset=$offset');

      final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/submissions$queryString',
      );
      final data = _apiClient.parseResponse(response);

      final submissionsList = data['submissions'] as List<dynamic>?;
      if (submissionsList == null) {
        return [];
      }

      final submissions = submissionsList
          .map((json) => SubmissionListItem.fromJson(json as Map<String, dynamic>))
          .toList();

      return submissions;
    } catch (e) {
      throw Exception('Failed to load submissions: $e');
    }
  }

  // Get single submission by ID
  Future<Submission> getSubmission(String id) async {
    try {
      final response = await _apiClient.get('${ApiConfig.apiBase}/submissions/$id');
      final data = _apiClient.parseResponse(response);

      return Submission.fromJson(data['submission'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load submission: $e');
    }
  }

  // Get all messages for a submission
  Future<List<MessageWithAuthor>> getMessages(String submissionId) async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/submissions/$submissionId/messages',
      );
      final data = _apiClient.parseResponse(response);

      final messagesList = data['messages'] as List<dynamic>?;
      if (messagesList == null) {
        return [];
      }

      final messages = messagesList
          .map((json) => MessageWithAuthor.fromJson(json as Map<String, dynamic>))
          .toList();

      return messages;
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  // Create new message in a submission
  Future<SubmissionMessage> createMessage(
    String submissionId,
    String content, {
    String? youtubeUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'content': content,
      };
      if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
        payload['youtube_url'] = youtubeUrl;
      }

      final response = await _apiClient.post(
        '${ApiConfig.apiBase}/submissions/$submissionId/messages',
        payload,
      );
      final data = _apiClient.parseResponse(response);

      return SubmissionMessage.fromJson(data['message'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create message: $e');
    }
  }

  // Mark a message as read
  Future<void> markMessageAsRead(String messageId) async {
    try {
      final response = await _apiClient.put(
        '${ApiConfig.apiBase}/messages/$messageId/read',
        {},
      );
      _apiClient.parseResponse(response);
    } catch (e) {
      throw Exception('Failed to mark message as read: $e');
    }
  }

  // Get unread message counts
  Future<UnreadCounts> getUnreadCount({String? programId}) async {
    try {
      final queryString = programId != null ? '?program_id=$programId' : '';
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/submissions/unread-count$queryString',
      );
      final data = _apiClient.parseResponse(response);

      return UnreadCounts.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }
}
