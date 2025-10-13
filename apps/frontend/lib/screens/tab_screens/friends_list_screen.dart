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
    return  Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('友達'),
      ),
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
      error: (e, _) => Center(child: Text('読み込みに失敗しました: $e')),
      data: (list) => RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(provider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _FriendsHeader(friendCount: list.length),
            const SizedBox(height: 16),
            if (list.isEmpty)
              _FriendsEmptyState(message: emptyText)
            else
              ...list.map((user) => _FriendCard(
                    user: user,
                    onOpenProfile: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(
                            userId: user.id,
                            initialUser: user,
                          ),
                        ),
                      );
                    },
                    onBlock: () => _handleBlock(context, ref, user),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBlock(BuildContext context, WidgetRef ref, User user) async {
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
  }
}

class _FriendsHeader extends StatelessWidget {
  const _FriendsHeader({required this.friendCount});

  final int friendCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryNavy,
            AppColors.softGold.withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryNavy.withOpacity(0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'つながった友達',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            friendCount == 0
                ? 'まだ友達はいません。まずはすれ違いタブでいいねしてみましょう！'
                : '$friendCount 人の友達とマッチしました。再会したらお祝いしよう！',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.92),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeaderChip(icon: Icons.favorite, label: 'いいねは匿名'),
              _HeaderChip(icon: Icons.chat_bubble_outline, label: 'SNSで連絡'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 12),
      child: Column(
        children: [
          Icon(
            Icons.auto_awesome,
            color: AppColors.textSecondary.withOpacity(0.35),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'すれ違いタブでいいねを送ってみましょう！',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.user,
    required this.onOpenProfile,
    required this.onBlock,
  });

  final User user;
  final VoidCallback onOpenProfile;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: AppColors.primaryNavy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpenProfile,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryNavy.withOpacity(0.12),
                      child: Text(
                        user.username.characters.first,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.faculty ?? '学部未設定'}・${_gradeLabel(user.grade)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.person),
                      label: const Text('プロフィールを見る'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onBlock,
                      icon: const Icon(Icons.block),
                      label: const Text('ブロック'),
                    ),
                  ],
                ),
                if (user.snsLinks != null && user.snsLinks!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: user.snsLinks!.entries
                          .where((entry) => entry.value.trim().isNotEmpty)
                          .map(
                            (entry) => Chip(
                              label: Text(
                                '${entry.key.toUpperCase()}: ${entry.value}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _gradeLabel(int? grade) {
    if (grade == null) return '学年未設定';
    switch (grade) {
      case 5:
        return 'M1';
      case 6:
        return 'M2';
      default:
        return '${grade}年';
    }
  }
}
