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

  // Register new user
  Future<User> register(String email, String password, String fullName) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.registerUrl,
        {
          'email': email,
          'password': password,
          'full_name': fullName,
        },
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
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  // Get current user profile
  Future<User> getCurrentUser() async {
    try {
      final response = await _apiClient.get(ApiConfig.profileUrl);
      final data = _apiClient.parseResponse(response);
      return User.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Update user profile
  Future<void> updateProfile({String? email, String? fullName}) async {
    try {
      final Map<String, dynamic> body = {};
      if (email != null) body['email'] = email;
      if (fullName != null) body['full_name'] = fullName;

      await _apiClient.put(ApiConfig.profileUrl, body);

      // Update stored email if changed
      if (email != null) {
        final userId = await _storage.getUserId();
        if (userId != null) {
          await _storage.saveUserInfo(userId, email);
        }
      }
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Change password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _apiClient.put(
        ApiConfig.changePasswordUrl,
        {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (e) {
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }
}
