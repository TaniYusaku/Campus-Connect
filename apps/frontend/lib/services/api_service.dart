import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:frontend/models/user.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RegisterResult {
  final bool success;
  final String? code; // e.g., 'email_exists', 'network', 'server'
  final String? message;
  const RegisterResult({required this.success, this.code, this.message});
  factory RegisterResult.ok() => const RegisterResult(success: true);
  factory RegisterResult.err(String code, String message) =>
      RegisterResult(success: false, code: code, message: message);
}

class ApiService {
  final _storage = const FlutterSecureStorage();
  // ベースURLは --dart-define で上書き可能（例: --dart-define=API_BASE_URL=http://192.168.0.79:3000/api）
  final String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.111.145:3000/api',
  );

  Future<RegisterResult> register({
    required String userName,
    required String email,
    required String password,
    required String faculty,
    required int grade,
    String? gender,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': userName,
          'email': email,
          'password': password,
          'faculty': faculty,
          'grade': grade,
          if (gender != null) 'gender': gender,
        }),
      );

      if (response.statusCode == 201) {
        return RegisterResult.ok();
      } else if (response.statusCode == 409) {
        return RegisterResult.err('email_exists', 'このメールアドレスは既に使われています');
      } else {
        return RegisterResult.err('server', '登録に失敗しました (${response.statusCode})');
      }
    } catch (e) {
      // Network or other errors
      return RegisterResult.err('network', 'ネットワークエラーが発生しました');
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
        final token = body['token'] as String?;
        final refresh = body['refreshToken'] as String?;
        if (refresh != null) {
          await _storage.write(key: 'refresh_token', value: refresh);
        }
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
        }
        return token;
      }
      return null;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<List<User>> getEncounters() async {
    final response = await _authorizedRequest((token) {
      return http.get(
        Uri.parse('$_baseUrl/users/encounters'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    });

    if (response != null && response.statusCode == 200) {
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
      final ts = (timestamp ?? DateTime.now()).toUtc().toIso8601String();
      final response = await _authorizedRequest((token) {
        return http.post(
          Uri.parse('$_baseUrl/encounters/observe'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'observedId': observedId,
            'rssi': rssi,
            'timestamp': ts,
          }),
        );
      });
      if (response == null) return;
      if (response.statusCode >= 400) {
        print('postObservation failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('postObservation error: $e');
    }
  }

  // 自分のプロフィールを取得
  Future<User?> getMe() async {
    final response = await _authorizedRequest((token) {
      return http.get(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    });
    if (response != null && response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(body);
    }
    return null;
  }

  // 自分のプロフィールを更新（部分更新）
  Future<User?> updateMe({
    String? userName,
    String? faculty,
    int? grade,
    String? bio,
    Map<String, String>? snsLinks,
    String? profilePhotoUrl,
    String? gender,
  }) async {
    final Map<String, dynamic> payload = {};
    if (userName != null) payload['userName'] = userName;
    if (faculty != null) payload['faculty'] = faculty;
    if (grade != null) payload['grade'] = grade;
    if (bio != null) payload['bio'] = bio;
    if (snsLinks != null) payload['snsLinks'] = snsLinks;
    if (profilePhotoUrl != null) payload['profilePhotoUrl'] = profilePhotoUrl;
    if (gender != null) payload['gender'] = gender;

    final response = await _authorizedRequest((token) {
      return http.put(
        Uri.parse('$_baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
    });
    if (response != null && response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(body);
    }
    return null;
  }

  // プロフィール写真アップロード用の署名付きURLを取得
  Future<({String uploadUrl, String objectPath, String publicUrl})?> requestProfilePhotoUploadUrl({
    required String contentType,
  }) async {
    final response = await _authorizedRequest((token) {
      return http.post(
        Uri.parse('$_baseUrl/users/me/profile-photo/upload-url'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({ 'contentType': contentType }),
      );
    });
    if (response != null && response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        uploadUrl: body['uploadUrl'] as String,
        objectPath: body['objectPath'] as String,
        publicUrl: body['publicUrl'] as String,
      );
    }
    return null;
  }

  // アップロード完了をサーバーへ通知してURLをプロファイルに反映
  Future<User?> confirmProfilePhoto({
    required String objectPath,
  }) async {
    final response = await _authorizedRequest((token) {
      return http.post(
        Uri.parse('$_baseUrl/users/me/profile-photo/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({ 'objectPath': objectPath }),
      );
    });
    if (response != null && response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(body);
    }
    return null;
  }

  // 認証付きリクエストを実行。401ならトークンを更新して1回だけリトライ。
  Future<http.Response?> _authorizedRequest(
      Future<http.Response> Function(String token) doRequest) async {
    String? token = await _storage.read(key: 'auth_token');
    if (token == null) return null;
    http.Response resp = await doRequest(token);
    if (resp.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed != null) {
        token = refreshed;
        resp = await doRequest(token);
      }
    }
    return resp;
  }

  Future<String?> _refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');
    if (refresh == null) return null;
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refresh}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final token = body['token'] as String?;
        final newRefresh = body['refreshToken'] as String?;
        if (token != null) {
          await _storage.write(key: 'auth_token', value: token);
        }
        if (newRefresh != null) {
          await _storage.write(key: 'refresh_token', value: newRefresh);
        }
        return token;
      } else {
        print('refresh failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('refresh error: $e');
      return null;
    }
  }
}
