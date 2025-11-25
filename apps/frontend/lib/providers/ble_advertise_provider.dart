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
  static const _kRegistrationDedupWindow = Duration(seconds: 30);
  String? _lastRegisteredId;
  DateTime? _lastRegisteredAt;
  String? _inFlightRegisterId;
  Future<bool>? _inFlightRegisterFuture;

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
    final initialOk = await _registerTempId(id, force: true);
    if (!initialOk) {
      // 失敗は即座にUIへは出さず、次回開始時の再試行でカバーする
      // ignore: avoid_print
      print('initial tempId registration failed; will retry on start.');
    }
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
      final ok = await _registerTempId(id);
      if (!ok) {
        // ignore: avoid_print
        print('tempId rotation registration failed for $id');
      }
    });
  }

  Future<bool> _registerTempId(String id, {bool force = false}) async {
    final now = DateTime.now();
    final recentlyRegistered =
        !force &&
        _lastRegisteredId == id &&
        _lastRegisteredAt != null &&
        now.difference(_lastRegisteredAt!) < _kRegistrationDedupWindow;
    if (recentlyRegistered) return true;

    if (_inFlightRegisterId == id && _inFlightRegisterFuture != null) {
      return await _inFlightRegisterFuture!;
    }

    final api = _ref.read(apiServiceProvider);
    final future = api.registerTempId(
      tempId: id,
      expiresAt: DateTime.now().add(const Duration(minutes: 16)),
    );
    _inFlightRegisterId = id;
    _inFlightRegisterFuture = future;
    final ok = await future;
    if (_inFlightRegisterId == id) {
      _inFlightRegisterId = null;
      _inFlightRegisterFuture = null;
    }
    if (ok) {
      _lastRegisteredId = id;
      _lastRegisteredAt = DateTime.now();
    }
    return ok;
  }

  Future<void> _ensureTempIdRegistered(String id) async {
    const attempts = 3;
    for (var i = 0; i < attempts; i++) {
      final ok = await _registerTempId(id, force: true);
      if (ok) return;
      // wait slightly longer each attempt to avoid immediate retries on flaky networks
      await Future.delayed(Duration(milliseconds: 600 * (i + 1)));
    }
    throw Exception('tempIdの登録に失敗しました。通信環境をご確認ください。');
  }

  Future<void> start() async {
    final currentId = await _svc.getOrCreateAdvertiseId();
    await _ensureTempIdRegistered(currentId);
    await _svc.start();
    final confirmedId = await _svc.getOrCreateAdvertiseId();
    state = state.copyWith(
      advertising: true,
      advertiseId: confirmedId,
      localName: 'CC-$confirmedId',
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
