import 'dart:async';
import 'package:flutter/foundation.dart'; // ValueNotifierのために追加
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/repositories/auth_repository.dart';
import 'package:campus_connect_app/repositories/encounter_repository.dart';
import 'package:campus_connect_app/services/ble_service_interface.dart';
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

  // ユーザーが設定画面に飛ばされたかどうかをUIに通知するためのNotifier
  final ValueNotifier<bool> userWasSentToSettingsNotifier = ValueNotifier(false);

  BleCoordinatorService(this._authRepository, this._encounterRepository, this._ref);

  /// BLE関連のパーミッションを要求する
  /// 権限が許可されなかった場合、またはpermanentlyDeniedの場合は例外を投げる
  Future<void> _requestPermissions() async {
    print("Requesting permissions sequentially...");

    final scanStatus = await Permission.bluetoothScan.request();
    print('[Permission] Permission.bluetoothScan: ${scanStatus.toString()}');

    final advertiseStatus = await Permission.bluetoothAdvertise.request();
    print('[Permission] Permission.bluetoothAdvertise: ${advertiseStatus.toString()}');

    // 1つでも「永久に拒否」があれば、アプリの設定画面を開く
    if (scanStatus.isPermanentlyDenied || advertiseStatus.isPermanentlyDenied) {
      print('Permissions are permanently denied. Opening app settings...');
      userWasSentToSettingsNotifier.value = true; // UIに通知
      await openAppSettings();
      throw Exception('Bluetooth permissions permanently denied. User sent to settings.');
    }

    // すべてのパーミッションが許可されているかチェック
    final bool allGranted = scanStatus.isGranted && advertiseStatus.isGranted;
    if (!allGranted) {
      print('Required Bluetooth permissions were not granted.');
      throw Exception('Required Bluetooth permissions were not granted.');
    }
    userWasSentToSettingsNotifier.value = false; // 権限が許可されたのでUIの状態をリセット
  }

  /// すれ違い通信サービスを開始する
  Future<void> start() async {
    print('Starting BLE coordinator service...');
    try {
      // 0. パーミッションの確認と要求
      await _requestPermissions(); // 権限がなければここで例外が投げられる

      // 1. バックエンドから一時IDを取得
      final tempId = await _authRepository.getTemporaryId();
      if (tempId == null) {
        throw Exception('Failed to get temporary ID from backend.');
      }

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
    } catch (e) {
      print('Failed to start BLE coordinator service: $e');
      rethrow; // エラーを呼び出し元に再スロー
    }
  }

  /// すれ違い通信サービスを停止する
  void stop() {
    _bleService.stopBleService();
    _deviceFoundSubscription?.cancel();
    print('BLE coordinator service stopped.');
  }
}
 