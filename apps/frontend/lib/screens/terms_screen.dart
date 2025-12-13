import 'package:flutter/material.dart';

class TermsScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  final bool showConsent;

  const TermsScreen({
    super.key,
    required this.onAccepted,
    this.showConsent = true,
  });

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TermsParagraph(
                        title: '1. 提供サービス',
                        body:
                            'Campus Connectは同じ大学に通う学生限定の交流サービスです。'
                            'アカウント登録時には学部や学年などの基本情報を正しく入力してください。',
                      ),
                      _TermsParagraph(
                        title: '2. すれ違い記録',
                        body:
                            'アプリは近くにいる端末と匿名のtempIdを交換し、最大24時間の範囲で履歴を表示します。'
                            '位置情報や連絡先などの個人情報はBLE通信では扱いません。',
                      ),
                      _TermsParagraph(
                        title: '3. いいねとマッチ',
                        body:
                            'すれ違い相手には匿名でいいねが送れます。相互にいいねすると友達として表示されますが、'
                            'チャット機能は提供されません。交流はSNSリンクや現実の再会を通じて行ってください。',
                      ),
                      _TermsParagraph(
                        title: '4. ブロックと安全',
                        body:
                            '不快な相手は即座にブロックできます。ブロックされた側には通知が届きません。'
                            '安全な利用のため、公序良俗に反する投稿や行為は禁止です。',
                      ),
                      _TermsParagraph(
                        title: '5. データとプライバシー',
                        body:
                            'Firebase上でユーザーデータを保護し、必要な範囲でのみ利用します。'
                            '詳細はプライバシーポリシーをご確認ください。',
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.showConsent) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _isChecked,
                  onChanged: (value) =>
                      setState(() => _isChecked = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('利用規約とプライバシーポリシーに同意します'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isChecked ? widget.onAccepted : null,
                  child: const Text('同意して次へ'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsParagraph extends StatelessWidget {
  final String title;
  final String body;

  const _TermsParagraph({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
