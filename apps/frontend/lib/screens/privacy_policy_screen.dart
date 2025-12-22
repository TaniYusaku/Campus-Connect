import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: const [
              _Section(
                title: '1. 収集する情報',
                body:
                    '・アカウント登録時に入力いただく氏名（ニックネーム）、大学メールアドレス、学部、学年、性別\n'
                    '・ログインに必要な認証トークン\n'
                    '・すれ違い機能のために端末間で交換される一時ID（tempId）\n'
                    '・アプリの安定運用に必要なクラッシュログや端末情報（OS種別・バージョン、機種名）',
              ),
              _Section(
                title: '2. 収集方法',
                body:
                    '・ユーザーが登録フォームへ入力することで取得します。\n'
                    '・Bluetooth Low Energy（BLE）で周囲の端末と匿名の一時IDを交換する際、検知したIDをアプリ内で保持します。\n'
                    '・アプリの利用状況や不具合調査のため、必要に応じて端末情報やクラッシュログを取得します。',
              ),
              _Section(
                title: '3. 利用目的',
                body:
                    '・本人確認およびログインのため\n'
                    '・すれ違い履歴やいいね機能など、アプリの主要機能を提供するため\n'
                    '・不正利用の防止、安全なコミュニティ運営のため\n'
                    '・機能改善や品質向上、問い合わせ対応のため\n'
                    '・法令遵守に必要な場合や、重要なお知らせを通知するため',
              ),
              _Section(
                title: '4. 位置情報・BLEの取り扱い',
                body:
                    '・アプリはBLEにより一時IDのみを交換し、位置情報や連絡先などの個人情報を通信しません。\n'
                    '・取得した一時IDは、すれ違い履歴の表示に必要な範囲でのみ一定期間保持します。',
              ),
              _Section(
                title: '5. データの保存期間',
                body:
                    '・認証トークンはログアウト時に削除します。\n'
                    '・すれ違い履歴や一時IDは、サービス提供に必要な期間のみ保持し、その後削除または匿名化します。\n'
                    '・ログや分析データは、運用上必要な最小限の期間に限定して保存します。',
              ),
              _Section(
                title: '6. 第三者提供',
                body:
                    '・法令に基づく場合や人の生命・財産の保護が必要な場合を除き、第三者へ個人情報を提供しません。\n'
                    '・サービス運営上必要なインフラ（Firebase等）を利用する場合、適切な管理のもとで取り扱います。',
              ),
              _Section(
                title: '7. 安全管理',
                body:
                    '・通信の暗号化やアクセス制御など、適切な安全管理措置を講じます。\n'
                    '・不要となった情報は速やかに削除または匿名化し、個人情報の漏えい防止に努めます。',
              ),
              _Section(
                title: '8. 利用者の権利',
                body:
                    '・ご自身の情報の確認・訂正・削除を希望される場合は、アプリ内の設定メニューからお問い合わせください。\n'
                    '・アカウント削除を実行すると、関連するデータは当社所定の方法で削除されます。',
              ),
              _Section(
                title: '9. オプトイン・オプトアウト',
                body:
                    '・通知の受け取りは、設定画面の「通知を受け取る」からいつでもオン/オフできます。\n'
                    '・すれ違い（BLE）機能は、アプリ内の開始/停止操作や端末のBluetooth設定で無効化できます。\n'
                    '・オプトアウトした場合、該当機能に関連するデータの収集・利用は停止または制限されます。',
              ),
              _Section(
                title: '10. 改定',
                body:
                    '・本ポリシーの内容は、必要に応じて改定することがあります。\n'
                    '・重要な変更がある場合は、アプリ内通知等でお知らせします。',
              ),
              _Section(
                title: '11. お問い合わせ',
                body:
                    '・本ポリシーに関するお問い合わせは、アプリ内の設定メニューからご連絡ください。',
              ),
              SizedBox(height: 8),
              Text(
                '最終更新日: 2025年12月22日',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

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
