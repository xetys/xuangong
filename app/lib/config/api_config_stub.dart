import 'dart:io' show Platform;

/// Get API URL for mobile platforms (iOS/Android)
String getApiUrl() {
  if (Platform.isIOS) {
    // iOS Simulator
    return 'http://localhost:8080';
  } else if (Platform.isAndroid) {
    // Android Emulator (10.0.2.2 maps to host's localhost)
    return 'http://10.0.2.2:8080';
  }
  // Default fallback
  return 'http://localhost:8080';
}
