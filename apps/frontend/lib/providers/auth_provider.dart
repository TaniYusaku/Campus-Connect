import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../providers/api_provider.dart';

enum AuthState { checking, authenticated, unauthenticated }

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(AuthState.checking) {
    checkAuthStatus();
  }
  final Ref _ref;
  final _storage = const FlutterSecureStorage();

  Future<void> checkAuthStatus() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      state = AuthState.authenticated;
    } else {
      state = AuthState.unauthenticated;
    }
  }

  Future<bool> login(String email, String password) async {
    final apiService = _ref.read(apiServiceProvider);
    final token = await apiService.login(email, password);
    if (token != null) {
      await _storage.write(key: 'auth_token', value: token);
      state = AuthState.authenticated;
      return true;
    } else {
      // ログイン失敗時のエラーハンドリング（必要なら）
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'auth_expires_at');
    state = AuthState.unauthenticated;
  }
} 
