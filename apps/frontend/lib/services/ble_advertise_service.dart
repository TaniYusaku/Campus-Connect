import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../shared/ble_constants.dart';

class BleAdvertiseService {
  BleAdvertiseService();

  final _storage = const FlutterSecureStorage();
  bool _initialized = false;
  bool _advertising = false;
  String? _advId;

  final _statusController = StreamController<({bool advertising, String? error})>.broadcast();
  Stream<({bool advertising, String? error})> get statusStream => _statusController.stream;

  Future<String> getOrCreateAdvertiseId() async {
    final existing = await _storage.read(key: 'advertise_id');
    if (existing != null && existing.isNotEmpty) {
      _advId = existing;
      return existing;
    }
    final rand = Random.secure();
    final bytes = List<int>.generate(4, (_) => rand.nextInt(256));
    final id = base64UrlEncode(bytes).replaceAll('=', ''); // short, URL-safe
    await _storage.write(key: 'advertise_id', value: id);
    _advId = id;
    return id;
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final req = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      if (req.values.any((s) => s.isPermanentlyDenied)) {
        // Best-effort: open app settings if permanently denied
        // ignore: unawaited_futures
        openAppSettings();
      }
    }
  }

  Future<void> _initGattIfNeeded() async {
    if (_initialized) return;
    await BlePeripheral.initialize();
    final id = await getOrCreateAdvertiseId();

    // Minimal GATT service so centrals can optionally read/subscribe to an ID.
    // iOS制約: value を事前に設定（=キャッシュ）する characteristic は
    // Read-Only でなければならない。
    // そのため、初期版は read のみで登録し、notify は付けない。
    await BlePeripheral.addService(
      BleService(
        uuid: kCcServiceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: kCcCharacteristicUuid,
            properties: [
              CharacteristicProperties.read.index,
            ],
            value: utf8.encode(id),
            permissions: [
              AttributePermissions.readable.index,
            ],
          ),
        ],
      ),
    );

    BlePeripheral.setAdvertisingStatusUpdateCallback((bool advertising, String? error) {
      _advertising = advertising;
      _statusController.add((advertising: advertising, error: error));
    });

    _initialized = true;
  }

  Future<void> start() async {
    if (_advertising) return;
    await _ensurePermissions();
    await _initGattIfNeeded();
    final id = await getOrCreateAdvertiseId();
    final localName = 'CC-$id';
    await BlePeripheral.startAdvertising(
      services: [kCcServiceUuid],
      localName: localName,
    );
  }

  Future<void> stop() async {
    await BlePeripheral.stopAdvertising();
  }

  bool get isAdvertising => _advertising;

  Future<void> updateId(String newId) async {
    _advId = newId;
    await _storage.write(key: 'advertise_id', value: newId);
    // Update characteristic value for connected subscribers
    // notify がない read-only characteristic なので、
    // 接続中に即通知は行わない（必要になれば read コールバック運用へ移行）。
    // ここではストレージの更新のみ。
  }

  void dispose() {
    _statusController.close();
  }
}
