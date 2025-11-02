import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

class ApiConfig {
  // Base URL configuration based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // Web platform - check for runtime environment variable
      try {
        final apiUrl = html.window.localStorage['API_URL'];
        if (apiUrl != null && apiUrl.isNotEmpty) {
          return apiUrl;
        }
      } catch (e) {
        // Fall back to default if localStorage not available
      }
      // Default for local web development
      return 'http://localhost:8080';
    } else if (Platform.isIOS) {
      // iOS Simulator
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      // Android Emulator (10.0.2.2 maps to host's localhost)
      return 'http://10.0.2.2:8080';
    }
    // Default fallback
    return 'http://localhost:8080';
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
