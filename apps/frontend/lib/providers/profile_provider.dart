import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';

final profileProvider = FutureProvider<User?>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getMe();
});

