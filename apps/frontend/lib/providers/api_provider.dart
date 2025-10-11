import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/services/api_service.dart';

/// Shared ApiService provider used across the app.
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
