import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_advertise_service.dart';
import 'api_provider.dart';

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

final bleAdvertiseProvider =
    StateNotifierProvider<BleAdvertiseNotifier, BleAdvertiseState>((ref) {
      final svc = ref.read(bleAdvertiseServiceProvider);
      return BleAdvertiseNotifier(svc, ref);
    });

class BleAdvertiseNotifier extends StateNotifier<BleAdvertiseState> {
  final BleAdvertiseService _svc;
  final Ref _ref;
  StreamSubscription<({bool advertising, String? error})>? _sub;
  StreamSubscription<String>? _idSub;

  BleAdvertiseNotifier(this._svc, this._ref)
    : super(
        const BleAdvertiseState(
          advertising: false,
          advertiseId: '',
          localName: '',
        ),
      ) {
    _init();
  }

  Future<void> _init() async {
    final id = await _svc.getOrCreateAdvertiseId();
    state = state.copyWith(advertiseId: id, localName: 'CC-$id');
    await _registerTempId(id);
    _sub = _svc.statusStream.listen((event) {
      state = state.copyWith(
        advertising: event.advertising,
        error: event.error,
      );
    });
    // Watch rotating tempId changes and register to server
    _idSub = _svc.idStream.listen((id) async {
      state = state.copyWith(advertiseId: id, localName: 'CC-$id');
      // best-effort: register to backend with 16min expiry
      await _registerTempId(id);
    });
  }

  Future<void> _registerTempId(String id) async {
    final api = _ref.read(apiServiceProvider);
    try {
      await api.registerTempId(
        tempId: id,
        expiresAt: DateTime.now().add(const Duration(minutes: 16)),
      );
    } catch (_) {
      // ignore register errors; observation fallback handles missing tempId
    }
  }

  Future<void> start() async {
    await _svc.start();
    final currentId = await _svc.getOrCreateAdvertiseId();
    state = state.copyWith(
      advertising: true,
      advertiseId: currentId,
      localName: 'CC-$currentId',
      error: null,
    );
  }

  Future<void> stop() async {
    await _svc.stop();
    state = state.copyWith(advertising: false);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _idSub?.cancel();
    super.dispose();
  }
}

// Auth状態に応じて自動的にアドバタイズ開始/停止を行うマネージャ
