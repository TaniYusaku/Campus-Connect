import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _storage = const FlutterSecureStorage();
  int _index = 0;

  Future<void> _finish() async {
    await _storage.write(key: 'onboarding_done', value: '1');
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildPage('すれ違い', '近くにいる学生を匿名で検知し、きっかけをつくります。'),
      _buildPage('いいね', '気になった相手にいいね。相手には通知されません。'),
      _buildPage('マッチ', '再びすれ違った瞬間にマッチ！SNSなどでつながれます。'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Connect')),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              children: pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: _finish, child: const Text('スキップ')),
                Row(
                  children: List.generate(
                    pages.length,
                    (i) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            i == _index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_index < pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      await _finish();
                    }
                  },
                  child: Text(_index < pages.length - 1 ? '次へ' : 'はじめる'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
