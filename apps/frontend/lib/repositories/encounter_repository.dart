import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final encounterRepositoryProvider = Provider((ref) => EncounterRepository());

class EncounterRepository {
  Future<void> recordEncounter(String tempId) async {
    print('Recording encounter with $tempId to backend...');
    // TODO: POST /api/encounters を呼び出す処理を実装
    // 例: await dio.post('/encounters', data: {'encounteredTempId': tempId});
  }
} 