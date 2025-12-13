import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/notification_preferences_provider.dart';
import 'package:frontend/screens/blocked_users_screen.dart';
import 'package:frontend/screens/profile_edit_screen.dart';
import 'package:frontend/screens/onboarding_screen.dart';
import 'package:frontend/screens/announcements_screen.dart';
import 'package:frontend/screens/privacy_policy_screen.dart';
import 'package:frontend/screens/terms_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _processing = false;

  Future<void> _navigateToProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
  }

  Future<void> _navigateToBlocked() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
    );
  }

  Future<void> _logout() async {
    setState(() => _processing = true);
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.of(context).pop();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text('すべてのデータが削除され、この操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing = true);
    final api = ref.read(apiServiceProvider);
    final ok = await api.deleteAccount();
    if (ok) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アカウントを削除しました')),
      );
    } else {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('アカウント削除に失敗しました')),
      );
    }
  }

  Future<void> _showTutorial() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(returnToCaller: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsEnabled = ref.watch(notificationPreferenceProvider);
    final notificationNotifier = ref.read(notificationPreferenceProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(label: 'アカウント'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('プロフィールを編集'),
            subtitle: const Text('学部や自己紹介、SNSリンクを変更'),
            onTap: _processing ? null : _navigateToProfile,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('通知を受け取る'),
            subtitle: const Text('アプリ内通知のオン/オフを切り替え'),
            value: notificationsEnabled,
            onChanged: _processing
                ? null
                : (value) async {
                    await notificationNotifier.setEnabled(value);
                  },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('ブロックしたユーザー'),
            subtitle: const Text('解除はできません'),
            onTap: _processing ? null : _navigateToBlocked,
          ),
          const Divider(height: 32),
          const _SectionHeader(label: 'サポート'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('利用規約'),
            onTap: _processing
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TermsScreen(
                          onAccepted: () {
                            Navigator.of(context).pop();
                          },
                          showConsent: false,
                        ),
                      ),
                    );
                  },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            onTap: _processing
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
          ),
          ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('運営からのお知らせ'),
            onTap: _processing
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AnnouncementsScreen(),
                      ),
                    );
                  },
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('チュートリアルをもう一度見る'),
            subtitle: const Text('オンボーディングを再確認'),
            onTap: _processing ? null : _showTutorial,
          ),
          const Divider(height: 32),
          const _SectionHeader(label: 'その他'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('ログアウト'),
            onTap: _processing ? null : _logout,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('アカウントを削除'),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: _processing ? null : _deleteAccount,
          ),
          if (_processing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
