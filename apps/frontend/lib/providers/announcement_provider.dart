import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/models/announcement.dart';
import 'package:frontend/providers/api_provider.dart';

final announcementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final items = await api.getAnnouncements();
  ref.read(announcementBadgeProvider.notifier).updateFromList(items);
  return items;
});

class AnnouncementBadgeNotifier extends StateNotifier<bool> {
  AnnouncementBadgeNotifier(this._ref) : super(false) {
    Future.microtask(_init);
  }

  final Ref _ref;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _key = 'announcements_last_read';
  DateTime? _lastRead;

  Future<void> _init() async {
    final stored = await _storage.read(key: _key);
    if (stored != null) {
      _lastRead = DateTime.tryParse(stored);
    }
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final api = _ref.read(apiServiceProvider);
      final items = await api.getAnnouncements();
      updateFromList(items);
    } catch (_) {
      // ignore network errors for badge
    }
  }

  void updateFromList(List<Announcement> items) {
    if (items.isEmpty) {
      state = false;
      return;
    }
    final latest = items.first.publishedAt;
    if (_lastRead == null || latest.isAfter(_lastRead!)) {
      state = true;
    } else {
      state = false;
    }
  }

  Future<void> markAsRead(DateTime? latest) async {
    if (latest == null) return;
    _lastRead = latest;
    await _storage.write(key: _key, value: latest.toIso8601String());
    state = false;
  }
}

final announcementBadgeProvider =
    StateNotifierProvider<AnnouncementBadgeNotifier, bool>(
  (ref) => AnnouncementBadgeNotifier(ref),
);
