import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/repositories/auth_repository.dart'; // import先は適宜修正
import 'package:campus_connect_app/repositories/encounter_repository.dart'; // import先は適宜修正
import 'package:campus_connect_app/services/ble_service_interface.dart'; // import先は適宜修正
import 'package:permission_handler/permission_handler.dart';

// Providerの定義
final bleCoordinatorServiceProvider = Provider((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final encounterRepository = ref.watch(encounterRepositoryProvider);
  return BleCoordinatorService(authRepository, encounterRepository, ref);
});

class BleCoordinatorService {
  final AuthRepository _authRepository;
  final EncounterRepository _encounterRepository;
  final Ref _ref;
  final BleServiceInterface _bleService = BleServiceInterface();
  StreamSubscription? _deviceFoundSubscription;

  BleCoordinatorService(this._authRepository, this._encounterRepository, this._ref);

  /// BLE関連のパーミッションを要求する
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ].request();

    // すべてのパーミッションが許可されているかチェック
    final bool allGranted = statuses.values.every((status) => status.isGranted);
    if (!allGranted) {
      print('Required Bluetooth permissions were not granted.');
      // オプション: ユーザーに設定画面を開くよう促すこともできる
      // openAppSettings();
    }
    return allGranted;
  }

  /// すれ違い通信サービスを開始する
  Future<void> start() async {
    print('Starting BLE coordinator service...');

    // 0. パーミッションの確認と要求
    final bool permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) {
      return; // 許可が得られなければ処理を中断
    }

    // 1. バックエンドから一時IDを取得
    final tempId = await _authRepository.getTemporaryId();

    if (tempId != null) {
      // 2. ネイティブのBLEサービスを開始
      await _bleService.startBleService(tempId);
      print('BLE service started with tempId: $tempId');

      // 3. デバイス発見イベントの購読を開始
      _deviceFoundSubscription?.cancel(); // 既存の購読はキャンセル
      _deviceFoundSubscription = _bleService.onDeviceFound.listen((foundTempId) {
        print('Device found with tempId: $foundTempId');
        // 4. バックエンドにすれ違いを報告
        _encounterRepository.recordEncounter(foundTempId);
      });

    } else {
      print('Could not start BLE service: Failed to get temporary ID.');
    }
  }

  /// すれ違い通信サービスを停止する
  void stop() {
    _bleService.stopBleService();
    _deviceFoundSubscription?.cancel();
    print('BLE coordinator service stopped.');
  }
} 