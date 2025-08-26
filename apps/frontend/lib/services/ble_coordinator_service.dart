import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/providers/encounter_provider.dart';
import 'package:campus_connect_app/repositories/auth_repository.dart';
import 'package:campus_connect_app/repositories/encounter_repository.dart';
import 'package:campus_connect_app/services/ble_service_interface.dart';
import 'package:permission_handler/permission_handler.dart';

// Providerの定義
final bleCoordinatorServiceProvider = Provider.autoDispose((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final encounterRepository = ref.watch(encounterRepositoryProvider);
  // refを渡す
  final service = BleCoordinatorService(ref, authRepository, encounterRepository);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class BleCoordinatorService {
  final Ref _ref;
  final AuthRepository _authRepository;
  final EncounterRepository _encounterRepository;
  final BleServiceInterface _bleService = BleServiceInterface();
  StreamSubscription? _deviceFoundSubscription;
  StreamSubscription? _bleStateSubscription;

  // UIに状態を通知するためのNotifier
  final ValueNotifier<bool> userWasSentToSettingsNotifier = ValueNotifier(false);
  final ValueNotifier<BleState> bleStateNotifier = ValueNotifier(BleState.unknown);
  final ValueNotifier<bool> isServiceRunningNotifier = ValueNotifier(false);

  BleCoordinatorService(this._ref, this._authRepository, this._encounterRepository) {
    // BLE状態の監視を開始
    _bleStateSubscription = _bleService.onBleStateChanged.listen((state) {
      bleStateNotifier.value = state;
      print('BLE state changed: $state');
      // BLEがオフ、または権限がない場合はサービスを停止
      if (state == BleState.poweredOff || state == BleState.unauthorized) {
        if (isServiceRunningNotifier.value) {
          stop();
          print('BLE service stopped due to state change: $state');
        }
      }
    });
  }

  void dispose() {
    stop();
    _bleStateSubscription?.cancel();
    userWasSentToSettingsNotifier.dispose();
    bleStateNotifier.dispose();
    isServiceRunningNotifier.dispose();
  }

  /// 個別の権限を要求するヘルパーメソッド
  Future<PermissionStatus> _checkAndRequestPermission(Permission permission) async {
    var status = await permission.status;
    if (status.isDenied) {
      status = await permission.request();
    }
    return status;
  }

  /// BLE関連のパーミッションを一つずつ要求し、結果を返す
  Future<bool> requestPermissions() async {
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
    ];

    for (final permission in permissions) {
      final status = await _checkAndRequestPermission(permission);
      if (status.isPermanentlyDenied) {
        userWasSentToSettingsNotifier.value = true;
        await openAppSettings();
        return false;
      }
      if (!status.isGranted) {
        return false;
      }
    }
    userWasSentToSettingsNotifier.value = false;
    return true;
  }

  /// すれ違い通信サービスを開始する
  Future<void> start() async {
    if (isServiceRunningNotifier.value) {
      print("BLE service is already running.");
      return;
    }

    // BLEがオンになっているか確認
    if (bleStateNotifier.value != BleState.poweredOn) {
        print("Cannot start BLE service: Bluetooth is not powered on.");
        return;
    }

    print('Starting BLE coordinator service...');
    try {
      final tempId = await _authRepository.getTemporaryId();
      if (tempId == null) {
        throw Exception('Failed to get temporary ID from backend.');
      }

      await _bleService.startBleService(tempId);
      print('BLE service started with tempId: $tempId');
      isServiceRunningNotifier.value = true;

      _deviceFoundSubscription?.cancel();
      _deviceFoundSubscription = _bleService.onDeviceFound.listen((foundTempId) async {
        print('Device found with tempId: $foundTempId');
        final encounteredUser = await _encounterRepository.recordEncounter(foundTempId);
        if (encounteredUser != null) {
          _ref.read(encounterProvider.notifier).addNewEncounter(encounteredUser);
          // TODO: UIにSnackBarなどで通知する
        }
      });
    } catch (e) {
      print('Failed to start BLE coordinator service: $e');
      isServiceRunningNotifier.value = false;
      rethrow;
    }
  }

  /// すれ違い通信サービスを停止する
  void stop() {
    if (!isServiceRunningNotifier.value) return;
    _bleService.stopBleService();
    _deviceFoundSubscription?.cancel();
    isServiceRunningNotifier.value = false;
    print('BLE coordinator service stopped.');
  }
}

 