import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/ble_service.dart';
import '../shared/ble_constants.dart';
import 'api_provider.dart';
import 'encounter_provider.dart';

final bleServiceProvider = Provider<BleService>((ref) => BleService());

// 連続スキャンモード（デフォルト: OFF）
class BoolPrefNotifier extends StateNotifier<bool> {
  final String key;
  final bool defaultValue;
  final _storage = const FlutterSecureStorage();
  BoolPrefNotifier({required this.key, required this.defaultValue})
    : super(defaultValue);
  Future<void> load() async {
    final v = await _storage.read(key: key);
    if (v == '1') state = true;
    if (v == '0') state = false;
  }

  Future<void> set(bool v) async {
    state = v;
    await _storage.write(key: key, value: v ? '1' : '0');
  }
}

// 連続スキャンモード（デフォルト: OFF）永続化
final continuousScanProvider = StateNotifierProvider<BoolPrefNotifier, bool>((
  ref,
) {
  final n = BoolPrefNotifier(key: 'pref_continuous_scan', defaultValue: false);
  n.load();
  return n;
});

// CCサービスUUIDでのスキャンフィルタを有効化（デフォルト: ON）永続化
final ccFilterProvider = StateNotifierProvider<BoolPrefNotifier, bool>((ref) {
  final n = BoolPrefNotifier(key: 'pref_cc_only', defaultValue: true);
  n.load();
  return n;
});

// RSSI しきい値（デフォルト -80dBm）
// RSSI しきい値（デフォルト -80dBm）を端末に保存して維持
final rssiThresholdProvider = StateNotifierProvider<RssiThresholdNotifier, int>(
  (ref) {
    final notifier = RssiThresholdNotifier();
    notifier.load(); // 非同期で保存値を反映
    return notifier;
  },
);

class RssiThresholdNotifier extends StateNotifier<int> {
  RssiThresholdNotifier() : super(-80);
  static const _key = 'rssi_threshold';
  final _storage = const FlutterSecureStorage();

  Future<void> load() async {
    final saved = await _storage.read(key: _key);
    final val = int.tryParse(saved ?? '');
    if (val != null) state = val;
  }

  Future<void> set(int value) async {
    state = value;
    await _storage.write(key: _key, value: value.toString());
  }
}

class BleScanState {
  final bool scanning;
  final List<ScanResult> results;
  final BluetoothAdapterState adapterState;

  const BleScanState({
    required this.scanning,
    required this.results,
    required this.adapterState,
  });

  BleScanState copyWith({
    bool? scanning,
    List<ScanResult>? results,
    BluetoothAdapterState? adapterState,
  }) => BleScanState(
    scanning: scanning ?? this.scanning,
    results: results ?? this.results,
    adapterState: adapterState ?? this.adapterState,
  );
}

final bleScanProvider = StateNotifierProvider<BleScanNotifier, BleScanState>((
  ref,
) {
  final service = ref.read(bleServiceProvider);
  return BleScanNotifier(service, ref);
});

class _ObservationRecord {
  final DateTime lastSent;
  final bool lastMutual;
  const _ObservationRecord({required this.lastSent, required this.lastMutual});
}

class BleScanNotifier extends StateNotifier<BleScanState> {
  final BleService _service;
  final Ref _ref;
  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<bool>? _scanStateSub;
  final Map<String, _ObservationRecord> _reported = {}; // advertiseId -> history
  bool _userRequestedScan = false;
  bool _autoRestartInProgress = false;
  Timer? _androidKeepAliveTimer;

  BleScanNotifier(this._service, this._ref)
    : super(
        const BleScanState(
          scanning: false,
          results: [],
          adapterState: BluetoothAdapterState.unknown,
        ),
      ) {
    _adapterSub = _service.adapterState.listen((s) {
      state = state.copyWith(adapterState: s);
    });
    _resultsSub = _service.scanResults.listen((list) {
      // Apply in-app CC filter for reliability across platforms
      final ccOnly = _ref.read(ccFilterProvider);
      final ccGuid = Guid(kCcServiceUuid);
      List<ScanResult> output = list;
      if (ccOnly) {
        output =
            list.where((r) {
              final ad = r.advertisementData;
              final hasName = ad.advName.startsWith(kCcLocalNamePrefix);
              final hasSvc = ad.serviceUuids.contains(ccGuid);
              return hasName || hasSvc;
            }).toList();
      }
      state = state.copyWith(results: output);
      _handleObservations(output);
    });
    _scanStateSub = _service.scanActiveStream.listen(_handleScanStateChanged);
  }

  Future<void> _handleObservations(List<ScanResult> list) async {
    final now = DateTime.now();
    for (final r in list) {
      // 現在のしきい値未満は送らない
      final threshold = _ref.read(rssiThresholdProvider);
      if (r.rssi < threshold) continue;
      final adName = r.advertisementData.advName;
      if (adName.startsWith(kCcLocalNamePrefix)) {
        final observedId = adName.substring(kCcLocalNamePrefix.length);
        final history = _reported[observedId];
        // 連続スキャン中であることをサーバーログから追跡できるように、
        // 相互遭遇後も2分ごとに最新観測を送る（サーバー側で5分クールダウン済み）。
        final wait = history?.lastMutual == true
            ? const Duration(minutes: 2)
            : const Duration(seconds: 30);
        if (history != null && now.difference(history.lastSent) <= wait) {
          debugPrint(
            '[BLE] skip observation for $observedId '
            '(last sent ${now.difference(history.lastSent).inSeconds}s ago)',
          );
          continue;
        }
        debugPrint(
          '[BLE] postObservation -> $observedId (rssi ${r.rssi})',
        );
        final api = _ref.read(apiServiceProvider);
        // Avoid同一IDがscan結果リストに複数残っているケースで一気にPOSTされるのを防ぐ
        _reported[observedId] = _ObservationRecord(
          lastSent: now,
          lastMutual: history?.lastMutual ?? false,
        );
        // fire-and-forget; errors are logged in ApiService
        // include rssi and timestamp
        final ok = await api.postObservation(
          observedId: observedId,
          rssi: r.rssi,
          timestamp: now,
        );
        if (ok) {
          debugPrint('[BLE] mutual encounter detected with $observedId');
          // Refresh encounter list when a mutual encounter is recorded
          _ref.invalidate(encounterListProvider);
        }
        _reported[observedId] = _ObservationRecord(
          lastSent: now,
          lastMutual: ok,
        );
        if (!ok) {
          debugPrint('[BLE] observation sent for $observedId (waiting for mutual)');
        }
      }
    }
  }

  Future<void> startScan() async {
    if (state.scanning) return;
    _userRequestedScan = true;
    try {
      await _startScanInternal();
    } catch (e) {
      _userRequestedScan = false;
      rethrow;
    }
  }

  Future<void> _startScanInternal() async {
    // Use unfiltered scan, then filter in-app for better cross-platform behavior
    final continuous = _ref.read(continuousScanProvider);
    final Duration? timeout = continuous ? null : const Duration(seconds: 10);
    await _service.startScan(
      timeout: timeout,
      filterCcService: false,
    );
    state = state.copyWith(scanning: true);
    _updateAndroidKeepAliveTimer();
  }

  Future<void> stopScan() async {
    _reported.clear();
    _userRequestedScan = false;
    _cancelAndroidKeepAliveTimer();
    if (!state.scanning) return;
    await _service.stopScan();
    state = state.copyWith(scanning: false);
  }

  void _handleScanStateChanged(bool active) {
    state = state.copyWith(scanning: active);
    if (!Platform.isAndroid) {
      return;
    }
    if (active || _autoRestartInProgress) return;
    final wantsRestart = _userRequestedScan && _ref.read(continuousScanProvider);
    if (wantsRestart) {
      _scheduleAutoRestart();
    } else {
      _userRequestedScan = false;
    }
  }

  Future<void> _scheduleAutoRestart() async {
    if (_autoRestartInProgress) return;
    _autoRestartInProgress = true;
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_userRequestedScan || !_ref.read(continuousScanProvider)) return;
      await _startScanInternal();
    } catch (e) {
      debugPrint('[BLE] auto restart failed: $e');
      _userRequestedScan = false;
    } finally {
      _autoRestartInProgress = false;
    }
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _adapterSub?.cancel();
    _scanStateSub?.cancel();
    _cancelAndroidKeepAliveTimer();
    super.dispose();
  }

  void _updateAndroidKeepAliveTimer() {
    if (!Platform.isAndroid) return;
    final wantsTimer = _userRequestedScan && _ref.read(continuousScanProvider);
    if (!wantsTimer) {
      _cancelAndroidKeepAliveTimer();
      return;
    }
    if (_androidKeepAliveTimer != null) return;
    _androidKeepAliveTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_restartScanForAndroidKeepAlive()),
    );
  }

  void _cancelAndroidKeepAliveTimer() {
    _androidKeepAliveTimer?.cancel();
    _androidKeepAliveTimer = null;
  }

  Future<void> _restartScanForAndroidKeepAlive() async {
    if (!Platform.isAndroid) return;
    if (!_userRequestedScan || !_ref.read(continuousScanProvider)) {
      _cancelAndroidKeepAliveTimer();
      return;
    }
    if (_autoRestartInProgress) return;
    _autoRestartInProgress = true;
    try {
      await _service.stopScan();
      state = state.copyWith(scanning: false);
      await Future.delayed(const Duration(milliseconds: 300));
      await _startScanInternal();
    } catch (e) {
      debugPrint('[BLE] keep-alive restart failed: $e');
      _userRequestedScan = false;
      _cancelAndroidKeepAliveTimer();
    } finally {
      _autoRestartInProgress = false;
    }
  }
}
