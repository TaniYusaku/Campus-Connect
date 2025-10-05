import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';

final friendsFutureProvider = FutureProvider<List<User>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getFriends();
});

final blockedFutureProvider = FutureProvider<List<User>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getBlockedUsers();
});

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(text: '友達'),
              Tab(text: 'ブロック中'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UsersList(
              provider: friendsFutureProvider,
              emptyText: 'まだ友達はいません',
              isBlockedList: false,
            ),
            _UsersList(
              provider: blockedFutureProvider,
              emptyText: 'ブロック中のユーザーはいません',
              isBlockedList: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList({required this.provider, required this.emptyText, required this.isBlockedList});
  final FutureProvider<List<User>> provider;
  final String emptyText;
  final bool isBlockedList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) => RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(provider.future);
        },
        child: list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 240),
                  Center(child: Text(emptyText)),
                ],
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final u = list[index];
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(u.username),
                    subtitle: Text('${u.faculty ?? ''} ${u.grade ?? ''}年'),
                    trailing: isBlockedList
                        ? IconButton(
                            tooltip: 'ブロック解除',
                            icon: const Icon(Icons.undo),
                            onPressed: () async {
                              final api = ref.read(apiServiceProvider);
                              final ok = await api.unblockUser(u.id);
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${u.username} のブロックを解除しました')),
                                );
                                // Refresh blocked and friends lists
                                await ref.refresh(blockedFutureProvider.future);
                                await ref.refresh(friendsFutureProvider.future);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ブロック解除に失敗しました')),
                                );
                              }
                            },
                          )
                        : IconButton(
                            tooltip: 'ブロック',
                            icon: const Icon(Icons.block),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('ブロックしますか？'),
                                  content: Text('${u.username} をブロックします。以降すれ違い/友達に表示されません。'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ブロック')),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              final api = ref.read(apiServiceProvider);
                              final ok = await api.blockUser(u.id);
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ブロックしました')),
                                );
                                // Refresh both lists
                                await ref.refresh(friendsFutureProvider.future);
                                await ref.refresh(blockedFutureProvider.future);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('ブロックに失敗しました')),
                                );
                              }
                            },
                          ),
                  );
                },
              ),
      ),
    );
  }
}
