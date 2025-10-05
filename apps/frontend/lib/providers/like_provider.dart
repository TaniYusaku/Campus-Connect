import 'package:flutter_riverpod/flutter_riverpod.dart';

class LikedSetNotifier extends StateNotifier<Set<String>> {
  LikedSetNotifier() : super(<String>{});
  void markLiked(String userId) => state = {...state, userId};
  void unmark(String userId) {
    final next = {...state};
    next.remove(userId);
    state = next;
  }
  bool isLiked(String userId) => state.contains(userId);
}

final likedSetProvider = StateNotifierProvider<LikedSetNotifier, Set<String>>(
  (ref) => LikedSetNotifier(),
);
