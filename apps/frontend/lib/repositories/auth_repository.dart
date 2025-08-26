import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/services/api_service.dart';

// このリポジトリは、認証状態そのものではなく、
// 認証が必要なAPI（一時ID取得など）へのアクセスを抽象化するために存在します。

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiServiceProvider)),
);

class AuthRepository {
  final ApiService _apiService;

  AuthRepository(this._apiService);

  /// バックエンドから一時IDを取得する
  Future<String?> getTemporaryId() async {
    try {
      // ApiService経由で、認証情報付きで一時IDを取得する
      final tempId = await _apiService.getTemporaryId();
      return tempId;
    } catch (e) {
      print('Failed to get temporary ID in AuthRepository: $e');
      return null;
    }
  }
} 