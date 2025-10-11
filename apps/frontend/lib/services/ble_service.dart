import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../shared/ble_constants.dart';

class BleService {
  StreamSubscription<List<ScanResult>>? _scanSub;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.onScanResults;

  Future<bool> isSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  Future<void> startScan({
    Duration? timeout, // null = 連続スキャン（タイムアウト無し）
    bool filterCcService = true,
  }) async {
    // Ensure permissions on Android (Android 12+: bluetoothScan/connect, <=11: location)
    await _ensurePermissions();
    // Wait for adapter on
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    if (filterCcService) {
      if (timeout != null) {
        await FlutterBluePlus.startScan(
          timeout: timeout,
          withServices: [Guid(kCcServiceUuid)],
        );
      } else {
        await FlutterBluePlus.startScan(withServices: [Guid(kCcServiceUuid)]);
      }
    } else {
      if (timeout != null) {
        await FlutterBluePlus.startScan(timeout: timeout);
      } else {
        await FlutterBluePlus.startScan();
      }
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> get isScanning async => await FlutterBluePlus.isScanningNow;

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final req =
          await [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            // For Android 11 or lower, location permission is required for BLE scans
            Permission.locationWhenInUse,
          ].request();
      if (req.values.any((s) => s.isPermanentlyDenied)) {
        // Best-effort: guide user to settings if denied permanently
        // ignore: unawaited_futures
        openAppSettings();
      }
    }
  }
}
