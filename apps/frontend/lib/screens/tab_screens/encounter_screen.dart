import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/encounter_provider.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/like_provider.dart';
import 'package:frontend/providers/liked_history_provider.dart';
import 'package:frontend/screens/tab_screens/friends_list_screen.dart';
import '../ble_scan_screen.dart';

class EncounterScreen extends ConsumerWidget {
  const EncounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounters = ref.watch(encounterListProvider);

    return Scaffold(
      body: encounters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
        data: (users) {
          final likedHistory = ref.watch(likedHistoryProvider);
          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(encounterListProvider.future);
              // also prune liked history
              await ref.read(likedHistoryProvider.notifier).purgeExpired();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Liked within 24h section
                if (likedHistory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.pink),
                        const SizedBox(width: 8),
                        Text('いいね済み（24時間以内）', style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                  ),
                  ...likedHistory.map((e) => ListTile(
                        leading: const Icon(Icons.favorite, color: Colors.pink),
                        title: Text(e.username),
                        subtitle: Text('${e.faculty ?? '学部未設定'} ${e.grade ?? '-'}年'),
                      )),
                  const Divider(height: 24),
                ],
                if (users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 240),
                    child: Center(child: Text('まだ誰もすれ違っていません。')),
                  )
                else
                  ...List.generate(users.length, (index) {
                    final user = users[index];
                    final liked = ref.watch(likedSetProvider);
                    final isLiked = liked.contains(user.id);
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user.username),
                      subtitle: Text('${user.faculty} ${user.grade}年'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: isLiked ? 'いいねを取り消す' : 'いいね',
                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.pink : null),
                            onPressed: () async {
                              final api = ref.read(apiServiceProvider);
                              if (!isLiked) {
                                final res = await api.likeUser(user.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res.ok ? (res.matchCreated ? 'いいねしました（友達になりました）' : 'いいねしました') : 'いいねに失敗しました')),
                                );
                                if (res.ok) {
                                  ref.read(likedSetProvider.notifier).markLiked(user.id);
                                  await ref.read(likedHistoryProvider.notifier).addFromUser(user);
                                  if (res.matchCreated) {
                                    ref.invalidate(friendsFutureProvider);
                                  }
                                }
                              } else {
                                final ok = await api.unlikeUser(user.id);
                                if (!context.mounted) return;
                                if (ok) {
                                  ref.read(likedSetProvider.notifier).unmark(user.id);
                                  await ref.read(likedHistoryProvider.notifier).removeByUserId(user.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('いいねを取り消しました')), 
                                  );
                                } else {
                                  // 取り消し失敗（マッチ成立など）
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('取り消せませんでした（友達になっている場合はブロックをご利用ください）')),
                                  );
                                }
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'ブロック',
                            icon: const Icon(Icons.block),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('ブロックしますか？'),
                                  content: Text('${user.username} をブロックします。以降すれ違いに表示されません。'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ブロック')),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              final api = ref.read(apiServiceProvider);
                              final ok = await api.blockUser(user.id);
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ブロックしました')),
                                );
                                ref.invalidate(encounterListProvider);
                                // Also refresh friends list as blocked users are excluded
                                ref.invalidate(friendsFutureProvider);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ブロックに失敗しました')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const BleScanScreen()))
              .then((_) {
            // BLEスキャン画面から戻ったら最新のすれ違いを再取得
            ref.invalidate(encounterListProvider);
          });
        },
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('BLEスキャン (v0)'),
      ),
    );
  }
} 
