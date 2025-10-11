import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/blocked_users_provider.dart';
import 'package:frontend/models/user.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUsersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('ブロックしたユーザー')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('取得に失敗しました: $error'),
          ),
        ),
        data: (users) => RefreshIndicator(
          onRefresh: () async {
            await ref.refresh(blockedUsersProvider.future);
          },
          child: users.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    Center(child: Text('ブロックしているユーザーはいません')),
                  ],
                )
              : ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final user = users[index];
                    return _BlockedUserTile(user: user);
                  },
                ),
        ),
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_off_outlined),
      title: Text(user.username),
      subtitle: Text('${user.faculty ?? '学部未設定'} ${user.grade != null ? '${user.grade}年' : ''}'),
      trailing: const Text('解除不可'),
    );
  }
}
