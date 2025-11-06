import '../models/user.dart';
import '../models/program.dart';
import '../config/api_config.dart';
import 'api_client.dart';

class UserService {
  final ApiClient _apiClient = ApiClient();

  /// List all users (admin only)
  Future<List<User>> listUsers({int limit = 20, int offset = 0}) async {
    final response = await _apiClient.get(
      '${ApiConfig.apiBase}/users?limit=$limit&offset=$offset',
    );
    final data = _apiClient.parseResponse(response);

    final List<dynamic> usersJson = data['users'] ?? [];
    return usersJson.map((json) => User.fromJson(json)).toList();
  }

  /// Get user by ID (admin only)
  Future<User> getUser(String userId) async {
    final response = await _apiClient.get('${ApiConfig.apiBase}/users/$userId');
    final data = _apiClient.parseResponse(response);
    return User.fromJson(data);
  }

  /// Create a new user (admin only)
  Future<User> createUser({
    required String email,
    required String password,
    required String fullName,
    String role = 'student',
  }) async {
    final response = await _apiClient.post(
      '${ApiConfig.apiBase}/users',
      {
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role,
      },
    );
    final data = _apiClient.parseResponse(response);
    return User.fromJson(data);
  }

  /// Update user (admin only)
  Future<void> updateUser({
    required String userId,
    String? email,
    String? password,
    String? fullName,
    bool? isActive,
  }) async {
    final Map<String, dynamic> body = {};
    if (email != null) body['email'] = email;
    if (password != null) body['password'] = password;
    if (fullName != null) body['full_name'] = fullName;
    if (isActive != null) body['is_active'] = isActive;

    await _apiClient.put('${ApiConfig.apiBase}/users/$userId', body);
  }

  /// Delete user (admin only)
  Future<void> deleteUser(String userId) async {
    await _apiClient.delete('${ApiConfig.apiBase}/users/$userId');
  }

  /// Get programs for a specific user (admin only)
  Future<List<Program>> getUserPrograms(String userId) async {
    final response = await _apiClient.get('${ApiConfig.apiBase}/users/$userId/programs');
    final data = _apiClient.parseResponse(response);
    final List<dynamic> programsJson = data['programs'] ?? [];
    return programsJson.map((json) => Program.fromJson(json)).toList();
  }

  /// Update user role (admin only)
  Future<void> updateUserRole({
    required String userId,
    required String role, // 'admin' or 'student'
  }) async {
    await _apiClient.put(
      '${ApiConfig.apiBase}/users/$userId/role',
      {'role': role},
    );
  }
}
