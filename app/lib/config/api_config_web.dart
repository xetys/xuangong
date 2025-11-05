import 'dart:html' as html show window;

/// Get API URL for web platform
String getApiUrl() {
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
}
