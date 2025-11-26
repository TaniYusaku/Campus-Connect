import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/public_profile_provider.dart';
import 'package:frontend/shared/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
      return const Icon(Icons.close_rounded);
    default:
      return const Icon(Icons.link);
  }
}

String _snsLabel(String key) {
  final lower = key.toLowerCase();
  switch (lower) {
    case 'instagram':
      return 'Instagram';
    case 'x':
    case 'twitter':
      return 'X (旧Twitter)';
    case 'facebook':
      return 'Facebook';
    case 'tiktok':
      return 'TikTok';
    case 'line':
      return 'LINE';
    default:
      if (key.isEmpty) return 'SNS';
      return '${key[0].toUpperCase()}${key.length > 1 ? key.substring(1) : ''}';
  }
}

Widget buildPublicProfileContent(
  BuildContext context,
  User user, {
  VoidCallback? onEditProfile,
}) {
  final List<MapEntry<String, String>> snsEntries =
      user.snsLinks?.entries
              .map((entry) => MapEntry(entry.key, entry.value.trim()))
              .where((entry) => entry.value.isNotEmpty)
              .toList() ??
          const <MapEntry<String, String>>[];
  final bool hasSnsEntries = snsEntries.isNotEmpty;
  final bool isSelfView = onEditProfile != null;
  final bool canShowToFriend = user.isFriend && hasSnsEntries;
  final bool shouldShowSnsSection = isSelfView || canShowToFriend;
  final faculty = user.faculty ?? '学部未設定';
  final gradeLabel = _gradeLabel(user.grade);
  final genderLabel = user.gender ?? '未設定';
  final bio = user.bio?.trim() ?? '';
  final hasBio = bio.isNotEmpty;
  final canEdit = onEditProfile != null;

  // Nunito styles bring a playful Tinder-like tone without paid fonts.
  final bioTitleStyle = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  final bioBodyStyle = GoogleFonts.nunito(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textPrimary.withOpacity(0.9),
  );
  final placeholderStyle = bioBodyStyle.copyWith(
    color: AppColors.textSecondary.withOpacity(0.8),
  );
  final headerNameStyle = GoogleFonts.nunito(
    fontSize: 23,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  final headerMetaStyle = GoogleFonts.nunito(
    fontSize: 14,
    color: Colors.white.withOpacity(0.85),
  );
  final snsNoteStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
      );

  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            gradient: headerGradient,
            borderRadius: BorderRadius.circular(32),
          ),
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundImage:
                    (user.profilePhotoUrl != null && user.profilePhotoUrl!.isNotEmpty)
                        ? NetworkImage(user.profilePhotoUrl!)
                        : null,
                child: (user.profilePhotoUrl == null ||
                        user.profilePhotoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 46, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header uses Nunito for a softer hero name.
                    Text(
                      user.username,
                      style: headerNameStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$faculty・$gradeLabel・$genderLabel',
                      style: headerMetaStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      if (canEdit)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              // 唯一の編集導線としてこのボタンのみ残す。
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('プロフィールを編集'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryNavy,
                side: BorderSide(
                  color: AppColors.primaryNavy.withOpacity(0.4),
                  width: 1.2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自己紹介', style: bioTitleStyle),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                hasBio ? bio : '自己紹介文を追加してみましょう。',
                style: hasBio ? bioBodyStyle : placeholderStyle,
              ),
            ),
            const SizedBox(height: 28),
            if (shouldShowSnsSection) ...[
              Text('SNS', style: bioTitleStyle),
              const SizedBox(height: 12),
              if (hasSnsEntries)
                ...snsEntries.map(
                  (entry) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: _snsIcon(entry.key),
                      title: Text('${_snsLabel(entry.key)}: ${entry.value}'),
                      dense: true,
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '登録しているSNSはありません。プロフィール編集から追加できます。',
                    style: placeholderStyle,
                  ),
                ),
              if (isSelfView) ...[
                const SizedBox(height: 8),
                Text(
                  '※SNSは友達になった相手にのみ表示されます。',
                  style: snsNoteStyle ?? placeholderStyle,
                ),
              ],
            ],
          ],
        ),
      ),
    ],
  );
}
