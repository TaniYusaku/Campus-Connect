import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_advertise_service.dart';

final bleAdvertiseServiceProvider = Provider<BleAdvertiseService>((ref) {
  final svc = BleAdvertiseService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

class BleAdvertiseState {
  final bool advertising;
  final String? error;
  final String advertiseId;
  final String localName;

  const BleAdvertiseState({
    required this.advertising,
    required this.advertiseId,
    required this.localName,
    this.error,
  });

  BleAdvertiseState copyWith({
    bool? advertising,
    String? error,
    String? advertiseId,
    String? localName,
  }) => BleAdvertiseState(
        advertising: advertising ?? this.advertising,
        error: error,
        advertiseId: advertiseId ?? this.advertiseId,
        localName: localName ?? this.localName,
      );
}

final bleAdvertiseProvider = StateNotifierProvider<BleAdvertiseNotifier, BleAdvertiseState>((ref) {
  final svc = ref.read(bleAdvertiseServiceProvider);
  return BleAdvertiseNotifier(svc);
});

class BleAdvertiseNotifier extends StateNotifier<BleAdvertiseState> {
  final BleAdvertiseService _svc;
  StreamSubscription<({bool advertising, String? error})>? _sub;

  BleAdvertiseNotifier(this._svc)
      : super(const BleAdvertiseState(advertising: false, advertiseId: '', localName: '')) {
    _init();
  }

  Future<void> _init() async {
    final id = await _svc.getOrCreateAdvertiseId();
    state = state.copyWith(advertiseId: id, localName: 'CC-$id');
    _sub = _svc.statusStream.listen((event) {
      state = state.copyWith(advertising: event.advertising, error: event.error);
    });
  }

  Future<void> start() async {
    await _svc.start();
  }

  Future<void> stop() async {
    await _svc.stop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

