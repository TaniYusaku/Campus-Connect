import 'dart:async';

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

class BleScanNotifier extends StateNotifier<BleScanState> {
  final BleService _service;
  final Ref _ref;
  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  final Map<String, DateTime> _reported = {}; // advertiseId -> last sent time
  static const Duration _scanBurstDuration = Duration(seconds: 3);
  static const Duration _scanPauseDuration = Duration(milliseconds: 300);
  Completer<void>? _autoScanStopper;
  Future<void>? _autoScanLoop;

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
        final last = _reported[observedId];
        // rate-limit: send at most once per 15 minutes per ID (tempID window)
        if (last == null ||
            now.difference(last) > const Duration(minutes: 15)) {
          _reported[observedId] = now;
          final api = _ref.read(apiServiceProvider);
          // fire-and-forget; errors are logged in ApiService
          // include rssi and timestamp
          final ok = await api.postObservation(
            observedId: observedId,
            rssi: r.rssi,
            timestamp: now,
          );
          if (ok) {
            // Refresh encounter list when a mutual encounter is recorded
            _ref.invalidate(encounterListProvider);
          }
        }
      }
    }
  }

  Future<void> startScan() async {
    if (_autoScanLoop != null) return;
    final stopper = Completer<void>();
    final firstWindowReady = Completer<void>();
    _autoScanStopper = stopper;
    _autoScanLoop = _runAutoScanLoop(stopper, firstWindowReady);
    await firstWindowReady.future;
    if (stopper.isCompleted) {
      return;
    }
    state = state.copyWith(scanning: true);
  }

  Future<void> stopScan() async {
    final stopper = _autoScanStopper;
    final loop = _autoScanLoop;
    if (stopper == null || loop == null) {
      if (state.scanning) {
        state = state.copyWith(scanning: false);
      }
      await _service.stopScan();
      return;
    }
    if (!stopper.isCompleted) {
      stopper.complete();
    }
    state = state.copyWith(scanning: false);
    await loop;
  }

  @override
  void dispose() {
    if (_autoScanStopper != null && !_autoScanStopper!.isCompleted) {
      _autoScanStopper!.complete();
    }
    final loop = _autoScanLoop;
    _autoScanLoop = null;
    if (loop != null) {
      unawaited(loop);
    }
    unawaited(_service.stopScan());
    _resultsSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> _runAutoScanLoop(
    Completer<void> stopper,
    Completer<void> firstWindowReady,
  ) async {
    try {
      var hasStartedSuccessfully = false;
      while (!stopper.isCompleted) {
        try {
          await _service.startScan(filterCcService: false);
          hasStartedSuccessfully = true;
          if (!firstWindowReady.isCompleted) {
            firstWindowReady.complete();
          }
        } catch (e, st) {
          if (!hasStartedSuccessfully) {
            if (!firstWindowReady.isCompleted) {
              firstWindowReady.completeError(e, st);
            }
            break;
          }
          await _waitOrCancel(_scanPauseDuration, stopper);
          continue;
        }

        final canceledDuringActive =
            await _waitOrCancel(_scanBurstDuration, stopper);
        await _service.stopScan();
        if (canceledDuringActive) break;

        final canceledDuringIdle =
            await _waitOrCancel(_scanPauseDuration, stopper);
        if (canceledDuringIdle) break;
      }
    } finally {
      if (!firstWindowReady.isCompleted) {
        firstWindowReady.complete();
      }
      _autoScanLoop = null;
      _autoScanStopper = null;
      if (state.scanning) {
        state = state.copyWith(scanning: false);
      }
    }
  }

  Future<bool> _waitOrCancel(Duration duration, Completer<void> stopper) async {
    final result = await Future.any<bool>([
      Future.delayed(duration).then((_) => false),
      stopper.future.then((_) => true),
    ]);
    return result;
  }
}
