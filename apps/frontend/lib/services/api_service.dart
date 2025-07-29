import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:campus_connect_app/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class ApiService {
  final _storage = const FlutterSecureStorage();
  // ※ベースURLは自身の環境に合わせて変更してください
  final String _baseUrl = 'http://localhost:8088/api';

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

  // 認証ヘッダーを動的に生成するプライベートなヘルパーメソッドを追加
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    // trueを指定してトークンを強制リフレッシュ
    final idToken = await user.getIdToken(true);
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<List<User>> getEncounters() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/users/encounters'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<User> users = body.map((dynamic item) => User.fromJson(item)).toList();
      return users;
    } else {
      throw Exception('Failed to load encounters');
    }
  }
} 