import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/models/user.dart';
import 'package:campus_connect_app/services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final encounterListProvider = FutureProvider<List<User>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return apiService.getEncounters();
}); 