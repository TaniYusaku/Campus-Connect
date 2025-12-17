import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

enum NotificationCategory {
  repeatEncounter,
  newFriend,
  friendEncounter,
}

class InAppNotification {
  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    DateTime? timestamp,
    this.icon,
    this.duration = const Duration(seconds: 8),
  }) : timestamp = timestamp ?? DateTime.now();

  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final IconData? icon;
  final Duration duration;
  final DateTime timestamp;
}

class NotificationHistoryNotifier
    extends StateNotifier<List<InAppNotification>> {
  NotificationHistoryNotifier({this.maxEntries = 50}) : super(const []);

  final int maxEntries;

  void add(InAppNotification notification) {
    final next = [notification, ...state];
    state = next.length > maxEntries ? next.sublist(0, maxEntries) : next;
  }

  void clear() {
    state = const [];
  }
}

class InAppNotificationNotifier extends StateNotifier<List<InAppNotification>> {
  InAppNotificationNotifier(this._historyNotifier) : super(const []);

  final NotificationHistoryNotifier _historyNotifier;

  Future<void> _vibrate() async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (canVibrate) {
        await Vibration.vibrate(duration: 500);
      } else {
        await HapticFeedback.vibrate();
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  void show({
    required String title,
    required String message,
    required NotificationCategory category,
    IconData? icon,
    Duration duration = const Duration(seconds: 8),
  }) {
    final notification = InAppNotification(
      id: '${DateTime.now().microsecondsSinceEpoch}_$category',
      title: title,
      message: message,
      category: category,
      icon: icon,
      duration: duration,
    );
    state = [...state, notification];
    _historyNotifier.add(notification);
    unawaited(_vibrate());
    unawaited(Future.delayed(duration, () {
      dismiss(notification.id);
    }));
  }

  void dismiss(String id) {
    state = state.where((item) => item.id != id).toList();
  }

  void clear() {
    state = const [];
  }
}

final notificationHistoryProvider =
    StateNotifierProvider<NotificationHistoryNotifier, List<InAppNotification>>(
  (ref) => NotificationHistoryNotifier(),
);

final inAppNotificationProvider =
    StateNotifierProvider<InAppNotificationNotifier, List<InAppNotification>>(
  (ref) => InAppNotificationNotifier(
    ref.read(notificationHistoryProvider.notifier),
  ),
);
