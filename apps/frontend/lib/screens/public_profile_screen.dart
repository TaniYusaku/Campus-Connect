import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/public_profile_provider.dart';
import 'package:frontend/shared/app_theme.dart';
import 'package:frontend/shared/profile_constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialUser,
    this.forceFriendView = false,
  });

  final String userId;
  final User? initialUser;
  final bool forceFriendView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(publicProfileProvider(userId));
    final fallbackUser = initialUser;
    final displayUser = asyncProfile.maybeWhen(
      data: (value) => value ?? fallbackUser,
      orElse: () => fallbackUser,
    );

    bool treatAsFriend(User? user) {
      return forceFriendView ||
          initialUser?.isFriend == true ||
          user?.isFriend == true;
    }

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
          return buildPublicProfileContent(
            context,
            resolved,
            isFriendView: treatAsFriend(resolved),
          );
        },
        loading: () {
          if (displayUser != null) {
            return buildPublicProfileContent(
              context,
              displayUser,
              isFriendView: treatAsFriend(displayUser),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          if (displayUser != null) {
            return buildPublicProfileContent(
              context,
              displayUser,
              isFriendView: treatAsFriend(displayUser),
            );
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
      return const Icon(Icons.close);
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

Future<void> _launchSnsLink(
  BuildContext context,
  String platform,
  String handle,
) async {
  final trimmed = handle.trim();
  if (trimmed.isEmpty) return;

  final uri = _buildSnsUri(platform, trimmed);
  try {
    if (uri != null) {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return;
    }
  } catch (_) {
    // fall through to clipboard fallback
  }

  await Clipboard.setData(ClipboardData(text: trimmed));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$trimmed をクリップボードにコピーしました'),
      duration: const Duration(seconds: 2),
    ),
  );
}

Uri? _buildSnsUri(String platform, String handle) {
  final trimmed = handle.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return Uri.tryParse(trimmed);
  }
  final normalized = trimmed.startsWith('@') ? trimmed.substring(1) : trimmed;
  switch (platform.toLowerCase()) {
    case 'x':
    case 'twitter':
      return Uri.tryParse('https://x.com/$normalized');
    case 'instagram':
      return Uri.tryParse('https://www.instagram.com/$normalized');
    default:
      return null;
  }
}

Widget buildPublicProfileContent(
  BuildContext context,
  User user, {
  VoidCallback? onEditProfile,
  bool isFriendView = false,
}) {
  final List<MapEntry<String, String>> snsEntries =
      user.snsLinks?.entries
              .map((entry) => MapEntry(entry.key, entry.value.trim()))
              .where((entry) => entry.value.isNotEmpty)
              .toList() ??
          const <MapEntry<String, String>>[];
  final bool hasSnsEntries = snsEntries.isNotEmpty;
  final bool isSelfView = onEditProfile != null;
  final bool showSnsEntries =
      hasSnsEntries && (isSelfView || isFriendView || user.isFriend);
  final bool showSnsPlaceholder = isSelfView && !hasSnsEntries;
  final bool shouldShowSnsSection = showSnsEntries || showSnsPlaceholder;
  final faculty = user.faculty ?? '学部未設定';
  final gradeLabel = _gradeLabel(user.grade);
  final genderLabel = user.gender ?? '未設定';
  final bio = user.bio?.trim() ?? '';
  final hasBio = bio.isNotEmpty;
  final hobbies = user.hobbies;
  final place = user.place?.trim() ?? '';
  final activity = user.activity?.trim() ?? '';
  final mbti = user.mbti?.trim() ?? '';
  final hasMbti = mbti.isNotEmpty && mbti != '選択しない';
  final mbtiDisplay =
      hasMbti ? (kMbtiLabels[mbti] != null ? '$mbti（${kMbtiLabels[mbti]}）' : mbti) : '';
  final hasOptionalDetails =
      hobbies.isNotEmpty || place.isNotEmpty || activity.isNotEmpty || hasMbti;
  final canEdit = onEditProfile != null;

  // Nunito styles bring a playful Tinder-like tone without paid fonts.
  final scheme = Theme.of(context).colorScheme;
  final onBackground = scheme.onBackground;
  final onBackgroundMuted = onBackground.withOpacity(0.8);
  final bioTitleStyle = GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: onBackground,
  );
  final bioBodyStyle = GoogleFonts.nunito(
    fontSize: 16,
    height: 1.5,
    color: onBackground.withOpacity(0.9),
  );
  final placeholderStyle = bioBodyStyle.copyWith(
    color: onBackgroundMuted,
  );
  final headerNameStyle = GoogleFonts.nunito(
    fontSize: 23,
    fontWeight: FontWeight.w700,
    color: scheme.onPrimary,
  );
  final headerMetaStyle = GoogleFonts.nunito(
    fontSize: 14,
    color: scheme.onPrimary.withOpacity(0.85),
  );
  final snsNoteStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
        color: onBackgroundMuted,
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
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hasBio ? bio : '自己紹介文を追加してみましょう。',
                  style: hasBio ? bioBodyStyle : placeholderStyle,
              ),
            ),
            const SizedBox(height: 28),
            if (hasOptionalDetails) ...[
              Text('プロフィール詳細', style: bioTitleStyle),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hobbies.isNotEmpty) ...[
                      Text(
                        '趣味',
                        style: bioBodyStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: hobbies
                            .map((hobby) => Chip(
                                  label: Text(hobby),
                                  backgroundColor:
                                      scheme.surfaceVariant.withOpacity(0.7),
                                  labelStyle: TextStyle(color: onBackground),
                                ))
                            .toList(),
                      ),
                      if (place.isNotEmpty || activity.isNotEmpty || hasMbti)
                        const SizedBox(height: 12),
                    ],
                    if (place.isNotEmpty) ...[
                      Text(
                        'よくいる場所',
                        style: bioBodyStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(place, style: bioBodyStyle),
                      if (activity.isNotEmpty || hasMbti) const SizedBox(height: 12),
                    ],
                    if (activity.isNotEmpty) ...[
                      Text(
                        '活動',
                        style: bioBodyStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(activity, style: bioBodyStyle),
                      if (hasMbti) const SizedBox(height: 12),
                    ],
                    if (hasMbti) ...[
                      Text(
                        'MBTI',
                        style: bioBodyStyle.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(mbtiDisplay, style: bioBodyStyle),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],
            if (shouldShowSnsSection) ...[
              Text('SNS', style: bioTitleStyle),
              const SizedBox(height: 12),
              if (showSnsEntries)
                ...snsEntries.map(
                  (entry) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: _snsIcon(entry.key),
                      title: Text('${_snsLabel(entry.key)}: ${entry.value}'),
                      dense: true,
                      onTap: () => _launchSnsLink(context, entry.key, entry.value),
                    ),
                  ),
                ),
              if (showSnsPlaceholder)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
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
