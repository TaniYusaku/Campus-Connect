import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // userProfileProviderを監視し、その状態に応じてUIを構築
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール'),
        actions: [
          // TODO: 編集画面への遷移ボタンを後で実装
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {              
            },
          ),
        ],
      ),
      // AsyncValueのwhenを使って、データ、ローディング、エラーの各状態でUIを分岐
      body: userProfile.when(
        data: (user) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: <Widget>[
              const CircleAvatar(
                radius: 50,
                // TODO: プロフィール画像のURLをuser.profilePhotoUrlから読み込む
                child: Icon(Icons.person, size: 50),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user.userName ?? 'ななしさん',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('学部'),
                subtitle: Text(user.faculty ?? '未設定'),
              ),
              ListTile(
                leading: const Icon(Icons.grade),
                title: const Text('学年'),
                subtitle: Text(user.grade != null ? '${user.grade}年' : '未設定'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('自己紹介'),
                subtitle: Text(user.bio ?? '自己紹介がありません'),
                isThreeLine: true,
              ),
              // TODO: 趣味やSNSリンクの表示もここに追加
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラーが発生しました: $err')),
      ),
    );
  }
}
