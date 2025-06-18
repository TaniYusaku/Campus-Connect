import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ※ベースURLは自身の環境に合わせて変更してください
  final String _baseUrl = 'http://192.168.1.10:3000/api';

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
} 