import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Base URL configuration based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // Web platform
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

  // Program endpoints
  static String get myProgramsUrl => '$apiBase/my-programs';
  static String programsUrl(String id) => '$apiBase/programs/$id';

  // Request timeout
  static const Duration timeout = Duration(seconds: 30);
}
