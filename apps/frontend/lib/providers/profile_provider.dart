import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/auth_provider.dart';

// 認証状態に依存し、画面から離れたらキャッシュを破棄する
final profileProvider = FutureProvider.autoDispose<User?>((ref) async {
  // authState が変わると再取得される
  ref.watch(authProvider);
  final api = ref.read(apiServiceProvider);
  return api.getMe();
});
