import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';

final publicProfileProvider =
    FutureProvider.autoDispose.family<User?, String>((ref, userId) async {
  final api = ref.read(apiServiceProvider);
  return api.getPublicProfile(userId);
});
