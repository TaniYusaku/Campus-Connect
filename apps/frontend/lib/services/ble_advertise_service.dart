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
  Timer? _rotationTimer;
  final _idController = StreamController<String>.broadcast();

  static const _kIdKey = 'advertise_id';
  static const _kIdTsKey = 'advertise_id_ts';
  static const Duration _kRotationInterval = Duration(minutes: 5);

  final _statusController =
      StreamController<({bool advertising, String? error})>.broadcast();
  Stream<({bool advertising, String? error})> get statusStream =>
      _statusController.stream;
  Stream<String> get idStream => _idController.stream;

  Future<String> getOrCreateAdvertiseId() async {
    // Load current id and timestamp
    final existing = await _storage.read(key: _kIdKey);
    final tsStr = await _storage.read(key: _kIdTsKey);
    final now = DateTime.now();
    final ts = int.tryParse(tsStr ?? '');
    final isFresh =
        ts != null &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(ts)) <
            _kRotationInterval;
    if (existing != null && existing.isNotEmpty && isFresh) {
      _advId = existing;
      _idController.add(existing);
      return existing;
    }
    final id = _generateNewId();
    await _persistId(id, now);
    _advId = id;
    _idController.add(id);
    return id;
  }

  String _generateNewId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(4, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> _persistId(String id, DateTime now) async {
    await _storage.write(key: _kIdKey, value: id);
    await _storage.write(
      key: _kIdTsKey,
      value: now.millisecondsSinceEpoch.toString(),
    );
  }

  Future<void> _ensurePermissions() async {
    if (Platform.isAndroid) {
      final req =
          await [
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
            properties: [CharacteristicProperties.read.index],
            value: utf8.encode(id),
            permissions: [AttributePermissions.readable.index],
          ),
        ],
      ),
    );

    BlePeripheral.setAdvertisingStatusUpdateCallback((
      bool advertising,
      String? error,
    ) {
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
    // emit id to ensure registration happens immediately on start
    _idController.add(id);
    _scheduleNextRotation();
  }

  Future<void> stop() async {
    await BlePeripheral.stopAdvertising();
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  bool get isAdvertising => _advertising;

  Future<void> updateId(String newId) async {
    _advId = newId;
    await _persistId(newId, DateTime.now());
    _idController.add(newId);
    // Update characteristic value for connected subscribers
    // notify がない read-only characteristic なので、
    // 接続中に即通知は行わない（必要になれば read コールバック運用へ移行）。
    // ここではストレージの更新のみ。
  }

  void dispose() {
    _statusController.close();
    _rotationTimer?.cancel();
    _idController.close();
  }

  void _scheduleNextRotation() async {
    _rotationTimer?.cancel();
    final tsStr = await _storage.read(key: _kIdTsKey);
    final ts = int.tryParse(tsStr ?? '');
    final now = DateTime.now();
    Duration wait;
    if (ts != null) {
      final nextAt = DateTime.fromMillisecondsSinceEpoch(
        ts,
      ).add(_kRotationInterval);
      wait =
          nextAt.isAfter(now)
              ? nextAt.difference(now)
              : const Duration(seconds: 1);
    } else {
      wait = _kRotationInterval;
    }
    _rotationTimer = Timer(wait, () async {
      if (!_advertising) return; // nothing to rotate
      final newId = _generateNewId();
      await _persistId(newId, DateTime.now());
      _advId = newId;
      _idController.add(newId);
      // Restart advertising with new local name to reflect rotated ID
      try {
        await BlePeripheral.stopAdvertising();
      } catch (_) {}
      // Best-effort: update GATT characteristic value by re-adding service
      try {
        await BlePeripheral.addService(
          BleService(
            uuid: kCcServiceUuid,
            primary: true,
            characteristics: [
              BleCharacteristic(
                uuid: kCcCharacteristicUuid,
                properties: [CharacteristicProperties.read.index],
                value: utf8.encode(newId),
                permissions: [AttributePermissions.readable.index],
              ),
            ],
          ),
        );
      } catch (e) {
        // ignore errors; some platforms may not allow adding duplicate services
      }
      await BlePeripheral.startAdvertising(
        services: [kCcServiceUuid],
        localName: 'CC-$newId',
      );
      _scheduleNextRotation();
    });
  }
}
