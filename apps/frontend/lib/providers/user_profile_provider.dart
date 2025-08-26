import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/models/user.dart';
import 'package:campus_connect_app/services/api_service.dart';

// ユーザープロフィールの状態を管理するNotifier
class UserProfileNotifier extends StateNotifier<AsyncValue<User>> {
  UserProfileNotifier(this._apiService) : super(const AsyncValue.loading()) {
    _fetchUserProfile();
  }

  final ApiService _apiService;

  // ユーザー情報を非同期に取得し、状態を更新する
  Future<void> _fetchUserProfile() async {
    try {
      final user = await _apiService.getMyProfile();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  // ユーザー情報を更新する
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    // 現在の状態から更新前のユーザー情報を取得
    final previousState = state;
    // 即座にUIを楽観的更新（ローディング表示）
    state = const AsyncValue.loading();
    try {
      final updatedUser = await _apiService.updateMyProfile(data);
      state = AsyncValue.data(updatedUser);
    } catch (e, stack) {
      // エラーが発生した場合は、状態を元に戻す
      state = previousState;
      // エラーを再スローしてUI側でハンドリングできるようにする
      rethrow;
    }
  }
}

// UserProfileNotifierのインスタンスを提供するProvider
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<User>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return UserProfileNotifier(apiService);
});
