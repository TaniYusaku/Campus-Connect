import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../shared/ble_constants.dart';

class BleService {
  StreamSubscription<List<ScanResult>>? _scanSub;

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.onScanResults;

  Future<bool> isSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    bool filterCcService = true,
  }) async {
    // Wait for adapter on
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first;

    if (filterCcService) {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: [Guid(kCcServiceUuid)],
      );
    } else {
      await FlutterBluePlus.startScan(timeout: timeout);
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  Future<bool> get isScanning async => await FlutterBluePlus.isScanningNow;
}
