import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  // ベースURLは --dart-define で上書き可能（例: --dart-define=API_BASE_URL=http://192.168.0.79:3000/api）
  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.0.79:3000/api',
  );

  Future<bool> register({
    required String userName,
    required String email,
    required String password,
    required String faculty,
    required int grade,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userName': userName,
        'email': email,
        'password': password,
        'faculty': faculty,
        'grade': grade,
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      print('Failed to register: \\${response.body}');
      return false;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['token'];
      }
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<List<User>> getEncounters() async {
    final token = await _storage.read(key: 'auth_token');
    final response = await http.get(
      Uri.parse('$_baseUrl/users/encounters'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<User> users = body.map((dynamic item) => User.fromJson(item)).toList();
      return users;
    } else {
      throw Exception('Failed to load encounters');
    }
  }

  // 観測したアドバタイズIDをサーバーへ送信（仮API: POST /api/encounters/observe）
  Future<void> postObservation({
    required String observedId,
    required int rssi,
    DateTime? timestamp,
  }) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final ts = (timestamp ?? DateTime.now()).toUtc().toIso8601String();
      final response = await http.post(
        Uri.parse('$_baseUrl/encounters/observe'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'observedId': observedId,
          'rssi': rssi,
          'timestamp': ts,
        }),
      );
      if (response.statusCode >= 400) {
        print('postObservation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('postObservation error: $e');
    }
  }
} 
