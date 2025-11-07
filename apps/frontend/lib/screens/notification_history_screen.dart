import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:frontend/providers/in_app_notification_provider.dart';
import 'package:frontend/shared/app_theme.dart';

class NotificationHistoryScreen extends ConsumerWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(notificationHistoryProvider);
    final formatter = DateFormat('yyyy/MM/dd HH:mm');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知履歴'),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '履歴をクリア',
              onPressed: () {
                ref.read(notificationHistoryProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: history.isEmpty
          ? const _EmptyHistoryView()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemBuilder: (context, index) {
                final item = history[index];
                return Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _accentColor(context, item.category).withOpacity(0.15),
                      foregroundColor: _accentColor(context, item.category),
                      child: Icon(_iconForCategory(item.category)),
                    ),
                    title: Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          item.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatter.format(item.timestamp.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: history.length,
            ),
    );
  }

  IconData _iconForCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.repeatEncounter:
        return Icons.repeat;
      case NotificationCategory.newFriend:
        return Icons.celebration_outlined;
      case NotificationCategory.friendEncounter:
        return Icons.handshake_outlined;
    }
  }

  Color _accentColor(BuildContext context, NotificationCategory category) {
    switch (category) {
      case NotificationCategory.repeatEncounter:
        return AppColors.softGold;
      case NotificationCategory.newFriend:
        return Theme.of(context).colorScheme.primary;
      case NotificationCategory.friendEncounter:
        return AppColors.accentCrimson;
    }
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_outlined,
              size: 72,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'まだ通知履歴がありません',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '通知が届くとここに表示されます。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
