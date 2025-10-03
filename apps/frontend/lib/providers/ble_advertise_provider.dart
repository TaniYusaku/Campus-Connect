import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ble_advertise_service.dart';
import 'api_provider.dart';
import 'auth_provider.dart';

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
  return BleAdvertiseNotifier(svc, ref);
});

class BleAdvertiseNotifier extends StateNotifier<BleAdvertiseState> {
  final BleAdvertiseService _svc;
  final Ref _ref;
  StreamSubscription<({bool advertising, String? error})>? _sub;
  StreamSubscription<String>? _idSub;

  BleAdvertiseNotifier(this._svc, this._ref)
      : super(const BleAdvertiseState(advertising: false, advertiseId: '', localName: '')) {
    _init();
  }

  Future<void> _init() async {
    final id = await _svc.getOrCreateAdvertiseId();
    state = state.copyWith(advertiseId: id, localName: 'CC-$id');
    _sub = _svc.statusStream.listen((event) {
      state = state.copyWith(advertising: event.advertising, error: event.error);
    });
    // Watch rotating tempId changes and register to server
    _idSub = _svc.idStream.listen((id) async {
      state = state.copyWith(advertiseId: id, localName: 'CC-$id');
      // best-effort: register to backend with 16min expiry
      final api = _ref.read(apiServiceProvider);
      // ignore: unawaited_futures
      api.registerTempId(tempId: id, expiresAt: DateTime.now().add(const Duration(minutes: 16)));
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
    _idSub?.cancel();
    super.dispose();
  }
}

// Auth状態に応じて自動的にアドバタイズ開始/停止を行うマネージャ
final autoAdvertiseManagerProvider = Provider<void>((ref) {
  final auth = ref.watch(authProvider);
  final adv = ref.read(bleAdvertiseProvider.notifier);
  // 非同期だが待たない（ユーザー体験優先）
  if (auth == AuthState.authenticated) {
    // ignore: unawaited_futures
    adv.start();
  } else if (auth == AuthState.unauthenticated) {
    // ignore: unawaited_futures
    adv.stop();
  }
});
