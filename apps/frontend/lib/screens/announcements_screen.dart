import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/announcement_provider.dart';
import 'package:intl/intl.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('お知らせ')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('お知らせの取得に失敗しました: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('現在お知らせはありません。'));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (items.isNotEmpty) {
              ref
                  .read(announcementBadgeProvider.notifier)
                  .markAsRead(items.first.publishedAt);
            }
          });
          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(announcementsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final announcement = items[index];
                final formatted = DateFormat('yyyy/MM/dd').format(announcement.publishedAt);
                final isImportant = announcement.importance == 'important';
                return Card(
                  color: isImportant
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                announcement.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatted,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          announcement.body,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (announcement.linkUrl != null && announcement.linkUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('リンクを開く'),
                                      content: Text(
                                        'アプリ外のブラウザで以下のリンクを開いてください:\n${announcement.linkUrl}',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('閉じる'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('詳しく見る'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
