import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyAdminAccessTokenBackup = 'admin_access_token_backup';
  static const String _keyAdminRefreshTokenBackup = 'admin_refresh_token_backup';
  static const String _keyIsImpersonating = 'is_impersonating';
  static const String _keyImpersonatedUserId = 'impersonated_user_id';

  // Save tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  // Save user info
  Future<void> saveUserInfo(String userId, String email) async {
    await _storage.write(key: _keyUserId, value: userId);
    await _storage.write(key: _keyUserEmail, value: email);
  }

  // Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _keyUserId);
  }

  // Get user email
  Future<String?> getUserEmail() async {
    return await _storage.read(key: _keyUserEmail);
  }

  // Clear all stored data (logout)
  // NOTE: We explicitly delete individual keys instead of using deleteAll()
  // because on web, deleteAll() clears ALL localStorage items, including
  // the API_URL injected by Docker at runtime. This would break login after logout.
  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
    await _storage.delete(key: _keyAdminAccessTokenBackup);
    await _storage.delete(key: _keyAdminRefreshTokenBackup);
    await _storage.delete(key: _keyIsImpersonating);
    await _storage.delete(key: _keyImpersonatedUserId);
    // IMPORTANT: If you add new keys to this class, remember to delete them here too!
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // Impersonation methods
  Future<void> startImpersonation(String targetUserId, String targetAccessToken, String targetRefreshToken) async {
    // Backup current admin tokens
    final currentAccessToken = await getAccessToken();
    final currentRefreshToken = await getRefreshToken();

    if (currentAccessToken != null) {
      await _storage.write(key: _keyAdminAccessTokenBackup, value: currentAccessToken);
    }
    if (currentRefreshToken != null) {
      await _storage.write(key: _keyAdminRefreshTokenBackup, value: currentRefreshToken);
    }

    // Set impersonation flag and target user ID
    await _storage.write(key: _keyIsImpersonating, value: 'true');
    await _storage.write(key: _keyImpersonatedUserId, value: targetUserId);

    // Replace tokens with target user's tokens
    await saveTokens(targetAccessToken, targetRefreshToken);
  }

  Future<void> exitImpersonation() async {
    // Restore admin tokens from backup
    final adminAccessToken = await _storage.read(key: _keyAdminAccessTokenBackup);
    final adminRefreshToken = await _storage.read(key: _keyAdminRefreshTokenBackup);

    if (adminAccessToken != null && adminRefreshToken != null) {
      await saveTokens(adminAccessToken, adminRefreshToken);
    }

    // Clear impersonation data
    await _storage.delete(key: _keyAdminAccessTokenBackup);
    await _storage.delete(key: _keyAdminRefreshTokenBackup);
    await _storage.delete(key: _keyIsImpersonating);
    await _storage.delete(key: _keyImpersonatedUserId);
  }

  Future<bool> isImpersonating() async {
    final flag = await _storage.read(key: _keyIsImpersonating);
    return flag == 'true';
  }

  Future<String?> getImpersonatedUserId() async {
    return await _storage.read(key: _keyImpersonatedUserId);
  }
}
