import 'dart:convert';
import 'package:campus_connect_app/models/user.dart';
import 'package:campus_connect_app/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final encounterRepositoryProvider = Provider((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return EncounterRepository(apiService);
});

class EncounterRepository {
  final ApiService _apiService;

  EncounterRepository(this._apiService);

  /// すれ違いを記録し、成功した場合は相手のユーザー情報を返す
  Future<User?> recordEncounter(String tempId) async {
    print('Recording encounter with $tempId to backend...');
    try {
      final headers = await _apiService.getAuthHeaders();
      final response = await http.post(
        Uri.parse('${_apiService.baseUrl}/encounters'),
        headers: headers,
        body: jsonEncode({'tempId': tempId}),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return User.fromJson(body);
      } else {
        print('Failed to record encounter: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error recording encounter: $e');
      return null;
    }
  }

  /// すれ違ったユーザーのリストを取得する
  Future<List<User>> getEncounters() async {
    return _apiService.getEncounters();
  }
}
 