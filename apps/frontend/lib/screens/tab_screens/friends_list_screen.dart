import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/screens/public_profile_screen.dart';

final friendsFutureProvider = FutureProvider<List<User>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return api.getFriends();
});

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('友達')),
      body: _FriendsListView(
        provider: friendsFutureProvider,
        emptyText: 'まだ友達はいません',
      ),
    );
  }
}

class _FriendsListView extends ConsumerWidget {
  const _FriendsListView({required this.provider, required this.emptyText});
  final FutureProvider<List<User>> provider;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('読み込みに失敗しました: $e')),
      data:
          (list) => RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(provider.future);
            },
            child:
                list.isEmpty
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
                        final user = list[index];
                        return ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(user.username),
                          subtitle: Text(
                            '${user.faculty ?? ''} ${user.grade ?? ''}年',
                          ),
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
                          trailing: IconButton(
                            tooltip: 'ブロック',
                            icon: const Icon(Icons.block),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text('ブロックしますか？'),
                                      content: Text(
                                        '${user.username} をブロックします。以降すれ違い/友達に表示されません。',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
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
                                await ref.refresh(friendsFutureProvider.future);
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
