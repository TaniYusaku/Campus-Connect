import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NotificationPreferenceNotifier extends StateNotifier<bool> {
  NotificationPreferenceNotifier() : super(true) {
    _load();
  }

  static const _key = 'pref_notifications_enabled';
  final _storage = const FlutterSecureStorage();

  Future<void> _load() async {
    final stored = await _storage.read(key: _key);
    if (stored == null) return;
    if (stored == '1') {
      state = true;
    } else if (stored == '0') {
      state = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled ? '1' : '0');
  }
}

final notificationPreferenceProvider =
    StateNotifierProvider<NotificationPreferenceNotifier, bool>((ref) {
  return NotificationPreferenceNotifier();
});
