import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/public_profile_provider.dart';
import 'package:frontend/screens/profile_edit_screen.dart';
import 'package:frontend/screens/public_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfile = ref.watch(publicProfileProvider('me'));
    return RefreshIndicator(
      onRefresh: () async {
        await ref.refresh(publicProfileProvider('me').future);
      },
      child: asyncProfile.when(
        data: (user) {
          if (user == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 200),
                Center(child: Text('プロフィールが見つかりませんでした')),
              ],
            );
          }
          return buildPublicProfileContent(
            context,
            user,
            onEditProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const Scaffold(
                    body: SafeArea(child: ProfileEditScreen()),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const _LoadingView(),
        error: (error, stack) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('プロフィールの取得に失敗しました: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 200),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
