import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../shared/ble_constants.dart';
import '../screens/login_screen.dart'; // for apiServiceProvider

final bleServiceProvider = Provider<BleService>((ref) => BleService());

// RSSI しきい値（デフォルト -80dBm）
final rssiThresholdProvider = StateProvider<int>((ref) => -80);

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

final bleScanProvider =
    StateNotifierProvider<BleScanNotifier, BleScanState>((ref) {
  final service = ref.read(bleServiceProvider);
  return BleScanNotifier(service, ref);
});

class BleScanNotifier extends StateNotifier<BleScanState> {
  final BleService _service;
  final Ref _ref;
  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  final Map<String, DateTime> _reported = {}; // advertiseId -> last sent time

  BleScanNotifier(this._service, this._ref)
      : super(const BleScanState(
            scanning: false, results: [], adapterState: BluetoothAdapterState.unknown)) {
    _adapterSub = _service.adapterState.listen((s) {
      state = state.copyWith(adapterState: s);
    });
    _resultsSub = _service.scanResults.listen((list) {
      state = state.copyWith(results: list);
      _handleObservations(list);
    });
  }

  void _handleObservations(List<ScanResult> list) {
    final now = DateTime.now();
    for (final r in list) {
      final adName = r.advertisementData.advName;
      if (adName.startsWith(kCcLocalNamePrefix)) {
        final observedId = adName.substring(kCcLocalNamePrefix.length);
        final last = _reported[observedId];
        // rate-limit: send at most once per 5 minutes per ID
        if (last == null || now.difference(last) > const Duration(minutes: 5)) {
          _reported[observedId] = now;
          final api = _ref.read(apiServiceProvider);
          // fire-and-forget; errors are logged in ApiService
          // include rssi and timestamp
          api.postObservation(
            observedId: observedId,
            rssi: r.rssi,
            timestamp: now,
          );
        }
      }
    }
  }

  Future<void> startScan() async {
    if (state.scanning) return;
    await _service.startScan();
    state = state.copyWith(scanning: true);
    // when scan ends, update flag via onScanResults empty check is not reliable; poll isScanningNow
    // For simplicity, set a timer to reset scanning flag after typical timeout
    Future.delayed(const Duration(seconds: 11), () async {
      final scanningNow = await _service.isScanning;
      if (!scanningNow) {
        state = state.copyWith(scanning: false);
      }
    });
  }

  Future<void> stopScan() async {
    if (!state.scanning) return;
    await _service.stopScan();
    state = state.copyWith(scanning: false);
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _adapterSub?.cancel();
    super.dispose();
  }
}
