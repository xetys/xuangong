import '../config/api_config.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storage = StorageService();

  // Login
  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.loginUrl,
        {'email': email, 'password': password},
        requiresAuth: false,
      );

      final data = _apiClient.parseResponse(response);

      // Extract tokens from nested object
      final tokens = data['tokens'] as Map<String, dynamic>;

      // Save tokens
      await _storage.saveTokens(
        tokens['access_token'] as String,
        tokens['refresh_token'] as String,
      );

      // Parse and save user info
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _storage.saveUserInfo(user.id, user.email);

      return user;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Call logout endpoint (optional, to invalidate token on server)
      await _apiClient.post(ApiConfig.logoutUrl, {});
    } catch (e) {
      // Ignore errors on logout endpoint
    } finally {
      // Always clear local storage
      await _storage.clearAll();
    }
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  // Get stored user email (useful for displaying before full user fetch)
  Future<String?> getUserEmail() async {
    return await _storage.getUserEmail();
  }
}
