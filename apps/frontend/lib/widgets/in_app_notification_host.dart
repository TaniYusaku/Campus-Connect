import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/in_app_notification_provider.dart';
import 'package:frontend/shared/app_theme.dart';

class InAppNotificationHost extends ConsumerWidget {
  const InAppNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(inAppNotificationProvider);
    final notifier = ref.read(inAppNotificationProvider.notifier);
    final current = queue.isNotEmpty ? queue.first : null;

    return Stack(
      children: [
        child,
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: SafeArea(
            child: AnimatedSlide(
              offset: current == null ? const Offset(0, -1.2) : Offset.zero,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: current == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: current == null
                    ? const SizedBox.shrink()
                    : _NotificationBanner(
                        notification: current,
                        onDismiss: () => notifier.dismiss(current.id),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.notification,
    required this.onDismiss,
  });

  final InAppNotification notification;
  final VoidCallback onDismiss;

  IconData _iconForCategory() {
    return notification.icon ??
        switch (notification.category) {
          NotificationCategory.repeatEncounter => Icons.repeat,
          NotificationCategory.newFriend => Icons.celebration_outlined,
          NotificationCategory.friendEncounter => Icons.handshake_outlined,
        };
  }

  Color _accentColor(BuildContext context) {
    switch (notification.category) {
      case NotificationCategory.repeatEncounter:
        return AppColors.softGold;
      case NotificationCategory.newFriend:
        return Theme.of(context).colorScheme.primary;
      case NotificationCategory.friendEncounter:
        return AppColors.accentCrimson;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryNavy.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: _accentColor(context).withOpacity(0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _accentColor(context).withOpacity(0.14),
                foregroundColor: _accentColor(context),
                child: Icon(_iconForCategory()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                color: AppColors.textSecondary,
                tooltip: '閉じる',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
