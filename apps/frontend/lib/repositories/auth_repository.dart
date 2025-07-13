import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

class AuthRepository {
  // ... 既存のログイン、登録処理

  /// バックエンドから一時IDを取得する
  Future<String?> getTemporaryId() async {
    try {
      // TODO: 認証トークン付きで POST /api/auth/temporary-id を呼び出す
      // 例: final response = await dio.post('/auth/temporary-id');
      // if (response.statusCode == 200) {
      //   return response.data['tempId'];
      // }
      // return null;
      // 以下はダミー実装
      await Future.delayed(const Duration(seconds: 1));
      return 'dummy-temp-id-from-backend'; // ダミーIDを返す
    } catch (e) {
      print('Failed to get temporary ID: $e');
      return null;
    }
  }
} 