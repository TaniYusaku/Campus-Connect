import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/public_profile_provider.dart';
import 'package:frontend/shared/app_theme.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId, this.initialUser});

  final String userId;
  final User? initialUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(publicProfileProvider(userId));
    final fallbackUser = initialUser;
    final displayUser = asyncProfile.maybeWhen(
      data: (value) => value ?? fallbackUser,
      orElse: () => fallbackUser,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(displayUser?.username ?? 'プロフィール'),
      ),
      body: asyncProfile.when(
        data: (user) {
          final resolved = user ?? displayUser;
          if (resolved == null) {
            return const Center(child: Text('ユーザー情報を取得できませんでした'));
          }
          return buildPublicProfileContent(context, resolved);
        },
        loading: () {
          if (displayUser != null) {
            return buildPublicProfileContent(context, displayUser);
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          if (displayUser != null) {
            return buildPublicProfileContent(context, displayUser);
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('プロフィールの取得に失敗しました: $error'),
            ),
          );
        },
      ),
    );
  }
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

Widget _snsIcon(String key) {
  final lower = key.toLowerCase();
  switch (lower) {
    case 'instagram':
      return const Icon(Icons.camera_alt_outlined);
    case 'x':
    case 'twitter':
      return const Icon(Icons.alternate_email);
    default:
      return const Icon(Icons.link);
  }
}

Widget buildPublicProfileContent(BuildContext context, User user,
    {Widget? headerAction}) {
  final snsEntries =
      user.snsLinks?.entries.where((entry) => entry.value.trim().isNotEmpty).toList() ??
          const [];
  final canShowSns = user.isFriend && snsEntries.isNotEmpty;
  final faculty = user.faculty ?? '学部未設定';
  final gradeLabel = _gradeLabel(user.grade);
  final genderLabel = user.gender ?? '未設定';

  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: [
      Container(
        decoration: BoxDecoration(
          gradient: headerGradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage:
                  (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                      ? NetworkImage(user.profilePhotoUrl!)
                      : null,
              child: (user.profilePhotoUrl == null ||
                      user.profilePhotoUrl!.isEmpty)
                  ? const Icon(Icons.person, size: 48, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$faculty • $gradeLabel • $genderLabel',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (headerAction != null) ...[
              headerAction,
              const SizedBox(height: 20),
            ],
            if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
              Text('自己紹介', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                user.bio!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
            ],
            if (canShowSns) ...[
              Text('SNS', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...snsEntries.map(
                (entry) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: _snsIcon(entry.key),
                    title: Text(entry.key.toUpperCase()),
                    subtitle: Text(entry.value),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text('最近のアクティビティ',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'すれ違いや友達機能は今後さらに充実予定です。',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}
