import 'api_config_stub.dart'
    if (dart.library.html) 'api_config_web.dart';

class ApiConfig {
  // Base URL configuration based on platform
  static String get baseUrl {
    return getApiUrl();
  }

  // API endpoints
  static const String apiVersion = 'v1';
  static String get apiBase => '$baseUrl/api/$apiVersion';

  // Auth endpoints
  static String get loginUrl => '$apiBase/auth/login';
  static String get registerUrl => '$apiBase/auth/register';
  static String get refreshUrl => '$apiBase/auth/refresh';
  static String get logoutUrl => '$apiBase/auth/logout';
  static String get profileUrl => '$apiBase/auth/me';
  static String get changePasswordUrl => '$apiBase/auth/change-password';

  // Program endpoints
  static String get myProgramsUrl => '$apiBase/my-programs';
  static String programsUrl(String id) => '$apiBase/programs/$id';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
}
