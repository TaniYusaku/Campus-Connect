import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/screens/public_profile_screen.dart';
import 'package:frontend/shared/app_theme.dart';

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
      data: (list) => RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(provider.future);
        },
        child: list.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  Icon(Icons.people_outline,
                      size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Center(child: Text(emptyText)),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final user = list[index];
                  return Card(
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                        child: Text(user.username.characters.first),
                      ),
                      title: Text(user.username,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            '${user.faculty ?? '学部未設定'} ${user.grade ?? '-'}年',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
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
                            await ref.refresh(friendsFutureProvider.future);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ブロックに失敗しました')),
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
