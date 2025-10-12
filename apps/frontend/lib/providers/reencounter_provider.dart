import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReencounterEvent {
  final String friendId;
  final String displayName;
  final DateTime occurredAt;

  ReencounterEvent({
    required this.friendId,
    required this.displayName,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
}

class ReencounterState {
  final Set<String> notifiedFriendIds;
  final Queue<ReencounterEvent> pending;

  const ReencounterState({
    required this.notifiedFriendIds,
    required this.pending,
  });

  factory ReencounterState.initial() => ReencounterState(
        notifiedFriendIds: <String>{},
        pending: Queue<ReencounterEvent>(),
      );

  ReencounterEvent? get current => pending.isEmpty ? null : pending.first;
}

class ReencounterNotifier extends StateNotifier<ReencounterState> {
  ReencounterNotifier() : super(ReencounterState.initial());

  void enqueue({required String friendId, required String displayName}) {
    if (state.notifiedFriendIds.contains(friendId)) {
      return;
    }
    final nextNotified = {...state.notifiedFriendIds, friendId};
    final nextQueue = Queue<ReencounterEvent>()..addAll(state.pending);
    nextQueue.add(
      ReencounterEvent(friendId: friendId, displayName: displayName),
    );
    state = ReencounterState(notifiedFriendIds: nextNotified, pending: nextQueue);
  }

  void consumeCurrent() {
    if (state.pending.isEmpty) return;
    final nextQueue = Queue<ReencounterEvent>()..addAll(state.pending);
    nextQueue.removeFirst();
    state = ReencounterState(
      notifiedFriendIds: state.notifiedFriendIds,
      pending: nextQueue,
    );
  }
}

final reencounterProvider =
    StateNotifierProvider<ReencounterNotifier, ReencounterState>((ref) {
  return ReencounterNotifier();
});
