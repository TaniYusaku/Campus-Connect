import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/models/user.dart';

class LikedEntry {
  final String userId;
  final String username;
  final String? faculty;
  final int? grade;
  final int likedAtMs;

  LikedEntry({
    required this.userId,
    required this.username,
    this.faculty,
    this.grade,
    required this.likedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'faculty': faculty,
        'grade': grade,
        'likedAtMs': likedAtMs,
      };

  static LikedEntry fromJson(Map<String, dynamic> json) => LikedEntry(
        userId: json['userId'] as String,
        username: (json['username'] ?? '名無しさん') as String,
        faculty: json['faculty'] as String?,
        grade: (json['grade'] is int)
            ? json['grade'] as int
            : int.tryParse('${json['grade'] ?? ''}'),
        likedAtMs: (json['likedAtMs'] as num).toInt(),
      );
}

class LikedHistoryNotifier extends StateNotifier<List<LikedEntry>> {
  LikedHistoryNotifier() : super(const []);

  static const _key = 'liked_history_v1';
  final _storage = const FlutterSecureStorage();
  static const _ttlMs = 24 * 60 * 60 * 1000; // 24h

  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) {
      state = const [];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => LikedEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      final now = DateTime.now().millisecondsSinceEpoch;
      final fresh = list.where((e) => now - e.likedAtMs <= _ttlMs).toList()
        ..sort((a, b) => b.likedAtMs.compareTo(a.likedAtMs));
      state = fresh;
      // persist pruned
      await _save();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> addFromUser(User user) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final existing = state.where((e) => e.userId == user.id).toList();
    final entry = LikedEntry(
      userId: user.id,
      username: user.username,
      faculty: user.faculty,
      grade: user.grade,
      likedAtMs: nowMs,
    );
    List<LikedEntry> next;
    if (existing.isEmpty) {
      next = [entry, ...state];
    } else {
      // update timestamp and move to top
      next = [entry, ...state.where((e) => e.userId != user.id)];
    }
    state = next;
    await _save();
  }

  Future<void> purgeExpired() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fresh = state.where((e) => now - e.likedAtMs <= _ttlMs).toList();
    if (fresh.length != state.length) {
      state = fresh;
      await _save();
    }
  }

  Future<void> removeByUserId(String userId) async {
    final next = state.where((e) => e.userId != userId).toList();
    if (next.length != state.length) {
      state = next;
      await _save();
    }
  }

  Future<void> _save() async {
    final jsonList = state.map((e) => e.toJson()).toList();
    await _storage.write(key: _key, value: jsonEncode(jsonList));
  }
}

final likedHistoryProvider = StateNotifierProvider<LikedHistoryNotifier, List<LikedEntry>>((ref) {
  final n = LikedHistoryNotifier();
  // best-effort async load
  // ignore: unawaited_futures
  n.load();
  return n;
});
