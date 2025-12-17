import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const FriendsListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return  Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBack,
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
                            forceFriendView: true,
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
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本当にブロックしますか？'),
        content: const Text('ブロックは解除できません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ブロックする'),
          ),
        ],
      ),
    );
    if (doubleConfirmed != true) return;
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
                : '$friendCount 人と友達になりました。再会したら話しかけてみましょう！',
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
              _HeaderChip(icon: Icons.favorite, label: '友達とすれ違うと通知されます！'),
              _HeaderChip(icon: Icons.chat_bubble_outline, label: 'SNSをのぞいてみましょう！'),
              _HeaderChip(icon: Icons.lock, label: 'ブロック機能で安心安全に！'),
            
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
    final recentEncounter = _isRecentEncounter(user.lastEncounteredAt);
    final snsEntries = user.snsLinks?.entries
            .map((entry) => MapEntry(entry.key, entry.value.trim()))
            .where((entry) => entry.value.isNotEmpty)
            .toList() ??
        const <MapEntry<String, String>>[];
    final accentColors = recentEncounter
        ? [
            AppColors.accentCrimson.withOpacity(0.12),
            Colors.white,
          ]
        : [
            Colors.white,
            Colors.white,
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: accentColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 16),
              ),
            ],
            border: Border.all(
              color: recentEncounter
                  ? AppColors.accentCrimson.withOpacity(0.25)
                  : AppColors.outline,
            ),
          ),
          child: InkWell(
            onTap: onOpenProfile,
            borderRadius: BorderRadius.circular(26),
            splashColor: AppColors.primaryNavy.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FriendAvatar(user: user, highlight: recentEncounter),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user.username,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoPill(
                                  icon: Icons.school,
                                  label: user.faculty ?? '学部未設定',
                                ),
                                _InfoPill(
                                  icon: Icons.badge_outlined,
                                  label: _gradeLabel(user.grade),
                                ),
                                if (user.encounterCount > 1)
                                  _InfoPill(
                                    icon: Icons.repeat,
                                    label: '再会 ${user.encounterCount} 回',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((user.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      user.bio!.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (user.lastEncounteredAt != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          Icons.timelapse,
                          size: 18,
                          color: AppColors.textSecondary.withOpacity(0.9),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '最終すれ違い: ${_formatLastEncounter(user.lastEncounteredAt!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onOpenProfile,
                          icon: const Icon(Icons.person),
                          label: const Text('プロフィールを見る'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        onPressed: onBlock,
                        icon: const Icon(Icons.block),
                        tooltip: 'ブロックする',
                      ),
                    ],
                  ),
                  if (snsEntries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SNSでつながる',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: snsEntries
                                .map(
                                  (entry) => _SocialChip(
                                    platform: entry.key,
                                    handle: entry.value,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isRecentEncounter(DateTime? encounteredAt) {
    if (encounteredAt == null) return false;
    return DateTime.now().difference(encounteredAt).inHours < 24;
  }

  static String _gradeLabel(int? grade) {
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

  static String _formatLastEncounter(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return 'たった今';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    } else {
      return '${diff.inDays}日前';
    }
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.user, required this.highlight});

  final User user;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryNavy.withOpacity(0.08),
          backgroundImage:
              (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                  ? NetworkImage(user.profilePhotoUrl!)
                  : null,
          child:
              (user.profilePhotoUrl == null || user.profilePhotoUrl!.isEmpty)
                  ? Text(
                      user.username.characters.first,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryNavy,
                      ),
                    )
                  : null,
        ),
        if (highlight)
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentCrimson,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCrimson.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'NEW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  const _SocialChip({required this.platform, required this.handle});

  final String platform;
  final String handle;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForPlatform(platform);
    final label = handle.trim();

    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primaryNavy),
      label: Text(
        '${platform.toUpperCase()}: $label',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: label));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label をクリップボードにコピーしました'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: AppColors.paleGold.withOpacity(0.7),
    );
  }

  static IconData _iconForPlatform(String key) {
    switch (key.toLowerCase()) {
      case 'x':
      case 'twitter':
        return Icons.close;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'line':
        return Icons.chat_bubble_outline;
      default:
        return Icons.link;
    }
  }
}
