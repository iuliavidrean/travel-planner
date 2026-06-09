import 'dart:convert';
import '../config/app_config.dart';

import 'package:http/http.dart' as http;

class AuthService {
  static String get baseUrl => AppConfig.baseUrl;

  // Backend base URL
  //static const String baseUrl = 'http://localhost:8080';

  // cerere Login
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // JWT token din backend !!!
      return data['token'];
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    // Fallback eroare
    throw Exception('Login failed.');
  }

  // cerere Register
  static Future<void> register({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/auth/register');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic> && data['error'] != null) {
      throw Exception(data['error']);
    }

    // Fallback eroare
    throw Exception('Register failed.');
  }
}
