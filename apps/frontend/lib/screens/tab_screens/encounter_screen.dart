import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/ble_advertise_provider.dart';
import 'package:frontend/providers/ble_provider.dart';
import 'package:frontend/providers/encounter_provider.dart';
import 'package:frontend/providers/like_provider.dart';
import 'package:frontend/providers/liked_history_provider.dart';
import 'package:frontend/screens/public_profile_screen.dart';
import 'package:frontend/screens/tab_screens/friends_list_screen.dart';

class EncounterScreen extends ConsumerStatefulWidget {
  const EncounterScreen({super.key});

  @override
  ConsumerState<EncounterScreen> createState() => _EncounterScreenState();
}

class _EncounterScreenState extends ConsumerState<EncounterScreen> {
  bool _toggling = false;

  Future<void> _toggleScanAndAdvertise(bool running) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final scanNotifier = ref.read(bleScanProvider.notifier);
    final advNotifier = ref.read(bleAdvertiseProvider.notifier);
    final continuous = ref.read(continuousScanProvider.notifier);
    try {
      if (running) {
        await scanNotifier.stopScan();
        await advNotifier.stop();
        await continuous.set(false);
      } else {
        await continuous.set(true);
        try {
          await advNotifier.start();
        } catch (e) {
          await continuous.set(false);
          rethrow;
        }
        try {
          await scanNotifier.startScan();
        } catch (e) {
          await scanNotifier.stopScan();
          await advNotifier.stop();
          await continuous.set(false);
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('BLEの開始/停止に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final encounterAsync = ref.watch(encounterListProvider);
    final likedHistory = ref.watch(likedHistoryProvider);
    final likedSet = ref.watch(likedSetProvider);
    final scanState = ref.watch(bleScanProvider);
    final advState = ref.watch(bleAdvertiseProvider);

    final running = scanState.scanning || advState.advertising;
    final buttonLabel = running ? 'スキャン・広告を停止' : 'すれ違いスキャンを開始';
    final buttonIcon = running ? Icons.stop : Icons.play_arrow;
    final statusText =
        'スキャン: ${scanState.scanning ? '稼働中' : '停止中'} / '
        '広告: ${advState.advertising ? '稼働中 (${advState.localName.isNotEmpty ? advState.localName : 'ID未登録'})' : '停止中'}';

    final refreshEncounters = () async {
      await ref.refresh(encounterListProvider.future);
      await ref.read(likedHistoryProvider.notifier).purgeExpired();
    };

    final refreshLikes = () async {
      await ref.read(likedHistoryProvider.notifier).purgeExpired();
      await ref.refresh(encounterListProvider.future);
    };

    Widget buildEncounterTab() {
      return encounterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('エラー: $err'),
            ),
          ],
        ),
        data: (users) {
          final filtered = users
              .where((user) => !likedSet.contains(user.id))
              .toList();
          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: refreshEncounters,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('まだ誰もすれ違っていません。')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refreshEncounters,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = filtered[index];
                final isLiked = likedSet.contains(user.id);
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user.username),
                  subtitle: Text('${user.faculty} ${user.grade}年'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PublicProfileScreen(
                          userId: user.id,
                          initialUser: user,
                        ),
                      ),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: isLiked ? 'いいねを取り消す' : 'いいね',
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.pink : null,
                        ),
                        onPressed: () async {
                          final api = ref.read(apiServiceProvider);
                          if (!isLiked) {
                            final res = await api.likeUser(user.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res.ok
                                      ? (res.matchCreated
                                          ? 'いいねしました（友達になりました）'
                                          : 'いいねしました')
                                      : 'いいねに失敗しました',
                                ),
                              ),
                            );
                            if (res.ok) {
                              ref
                                  .read(likedSetProvider.notifier)
                                  .markLiked(user.id);
                              await ref
                                  .read(likedHistoryProvider.notifier)
                                  .addFromUser(user);
                              if (res.matchCreated) {
                                ref.invalidate(friendsFutureProvider);
                              }
                              DefaultTabController.of(context)?.animateTo(1);
                            }
                          } else {
                            final ok = await api.unlikeUser(user.id);
                            if (!context.mounted) return;
                            if (ok) {
                              ref
                                  .read(likedSetProvider.notifier)
                                  .unmark(user.id);
                              await ref
                                  .read(likedHistoryProvider.notifier)
                                  .removeByUserId(user.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('いいねを取り消しました'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '取り消せませんでした（友達になっている場合はブロックをご利用ください）',
                                  ),
                                ),
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
                              content: Text(
                                '${user.username} をブロックします。以降すれ違い/友達に表示されません。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('ブロック'),
                                ),
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
              },
            ),
          );
        },
      );
    }

    Widget buildLikedTab() {
      if (likedHistory.isEmpty) {
        return RefreshIndicator(
          onRefresh: refreshLikes,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 200),
              Center(child: Text('最近いいねしたユーザーはいません')),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: refreshLikes,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: likedHistory.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = likedHistory[index];
            final placeholderUser = User(
              id: entry.userId,
              username: entry.username,
              faculty: entry.faculty,
              grade: entry.grade,
              email: null,
              bio: null,
              profilePhotoUrl: null,
              snsLinks: null,
              gender: null,
            );
            return ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: Text(entry.username),
              subtitle: Text(
                '${entry.faculty ?? '学部未設定'} ${entry.grade ?? '-'}年',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PublicProfileScreen(
                      userId: entry.userId,
                      initialUser: placeholderUser,
                    ),
                  ),
                );
              },
              trailing: IconButton(
                tooltip: 'いいねを取り消す',
                icon: const Icon(Icons.favorite, color: Colors.pink),
                onPressed: () async {
                  final api = ref.read(apiServiceProvider);
                  final ok = await api.unlikeUser(entry.userId);
                  if (!context.mounted) return;
                  if (ok) {
                    ref.read(likedSetProvider.notifier).unmark(entry.userId);
                    await ref
                        .read(likedHistoryProvider.notifier)
                        .removeByUserId(entry.userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('いいねを取り消しました')),
                    );
                    await refreshEncounters();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('取り消せませんでした')),
                    );
                  }
                },
              ),
            );
          },
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          _toggling ? null : () => _toggleScanAndAdvertise(running),
                      icon: Icon(buttonIcon),
                      label: Text(_toggling ? '処理中...' : buttonLabel),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (advState.error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '広告エラー: ${advState.error}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.redAccent),
                      ),
                    ],
                  ],
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'すれ違い'),
                  Tab(text: 'いいね'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    buildEncounterTab(),
                    buildLikedTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
