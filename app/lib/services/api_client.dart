import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiClient {
  final StorageService _storage = StorageService();

  // Helper to get headers with auth token
  Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // GET request
  Future<http.Response> get(String url, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(includeAuth: requiresAuth);
    return await http
        .get(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
  }

  // POST request
  Future<http.Response> post(
    String url,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(includeAuth: requiresAuth);
    return await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
  }

  // PUT request
  Future<http.Response> put(
    String url,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    final headers = await _getHeaders(includeAuth: requiresAuth);
    return await http
        .put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
  }

  // DELETE request
  Future<http.Response> delete(String url, {bool requiresAuth = true}) async {
    final headers = await _getHeaders(includeAuth: requiresAuth);
    return await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(ApiConfig.timeout);
  }

  // Parse response and handle errors
  dynamic parseResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized - Please login again');
    } else if (response.statusCode == 404) {
      throw Exception('Resource not found');
    } else if (response.statusCode == 500) {
      throw Exception('Server error - Please try again later');
    } else {
      // Try to parse error message from response
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? error['message'] ?? 'Request failed');
      } catch (_) {
        throw Exception('Request failed with status ${response.statusCode}');
      }
    }
  }
}
