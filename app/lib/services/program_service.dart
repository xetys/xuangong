import '../models/program.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class ProgramService {
  final ApiClient _apiClient = ApiClient();

  // Get user's personal programs
  Future<List<Program>> getMyPrograms() async {
    try {
      final response = await _apiClient.get('${ApiConfig.apiBase}/my-programs');
      print('My programs response status: ${response.statusCode}');
      print('My programs response body: ${response.body}');

      final data = _apiClient.parseResponse(response);
      print('Parsed data: $data');

      final programs = (data['programs'] as List<dynamic>)
          .map((json) => Program.fromJson(json as Map<String, dynamic>))
          .toList();

      return programs;
    } catch (e, stackTrace) {
      print('Error in getMyPrograms: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load your programs: $e');
    }
  }

  // Get public templates
  Future<List<Program>> getTemplates() async {
    try {
      final response = await _apiClient.get(
        '${ApiConfig.apiBase}/programs?is_template=true&is_public=true',
      );
      final data = _apiClient.parseResponse(response);

      final templates = (data['programs'] as List<dynamic>)
          .map((json) => Program.fromJson(json as Map<String, dynamic>))
          .toList();

      return templates;
    } catch (e) {
      throw Exception('Failed to load templates: $e');
    }
  }

  // Get single program with exercises
  Future<Program> getProgram(String id) async {
    try {
      final response = await _apiClient.get('${ApiConfig.apiBase}/programs/$id');
      final data = _apiClient.parseResponse(response);

      return Program.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to load program: $e');
    }
  }

  // Create new program
  Future<Program> createProgram(Program program, {String? ownedByUserId}) async {
    try {
      final payload = program.toJson();
      // If ownedByUserId is provided, add it to the payload
      if (ownedByUserId != null) {
        payload['owned_by_user_id'] = ownedByUserId;
      }
      print('Creating program with payload: $payload');
      final response = await _apiClient.post(
        '${ApiConfig.apiBase}/programs',
        payload,
      );
      final data = _apiClient.parseResponse(response);

      return Program.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      print('Error creating program: $e');
      throw Exception('Failed to create program: $e');
    }
  }

  // Update existing program
  Future<void> updateProgram(String id, Program program) async {
    try {
      final response = await _apiClient.put(
        '${ApiConfig.apiBase}/programs/$id',
        program.toJson(),
      );
      _apiClient.parseResponse(response);
    } catch (e) {
      throw Exception('Failed to update program: $e');
    }
  }

  // Delete program
  Future<void> deleteProgram(String id) async {
    try {
      final response = await _apiClient.delete('${ApiConfig.apiBase}/programs/$id');
      _apiClient.parseResponse(response);
    } catch (e) {
      throw Exception('Failed to delete program: $e');
    }
  }
}
