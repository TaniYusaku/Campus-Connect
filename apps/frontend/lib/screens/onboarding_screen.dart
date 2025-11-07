import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/shared/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.returnToCaller = false});

  final bool returnToCaller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.body,
    required this.tips,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String body;
  final List<String> tips;
  final IconData icon;
  final List<Color> gradient;
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _storage = const FlutterSecureStorage();
  int _index = 0;

  late final List<_OnboardingStep> _steps = [
    _OnboardingStep(
      title: 'Bluetooth をオンに',
      body: 'Campus Connect は近くにいる学生を BLE で検知します。',
      tips: const [
        'Bluetoothの許可をオンにしてください。',
        '省電力モードをオフにすると検知が安定します。',
        '⚠️アプリを閉じたら検知が止まります。',
      ],
      icon: Icons.bluetooth_searching,
      gradient: const [Color(0xFF0E3A64), Color(0xFF22629B)],
    ),
    _OnboardingStep(
      title: '気になる相手にいいね',
      body: 'すれ違い一覧から “いいね” を送ると、相手には匿名のままいいねが届きます。',
      tips: const [
        'あなたが送ったことは相手に知らされません。',
        'すれ違い、いいねは 24 時間後に自動的削除されます。',
      ],
      icon: Icons.favorite_border,
      gradient: const [Color(0xFF5F2C82), Color(0xFF49A09D)],
    ),
    _OnboardingStep(
      title: '再会したらマッチ',
      body: '相互にいいねした時点で互いの友達リストに追加されます。',
      tips: const [
        'マッチ後はプロフィールの SNS から連絡が取れます。',
        'ブロックすればいつでも関係をリセットできます。',
      ],
      icon: Icons.auto_awesome,
      gradient: const [Color(0xFF512DA8), Color(0xFF9575CD)],
    ),
    _OnboardingStep(
      title: '安全に楽しみ、友達を作りましょう',
      body: '困った相手はすぐにブロック。アプリ内では本名も公開されません。',
      tips: const [
        'ブロックすると以後お互いのリストに表示されません。',
        'プロフィールは丁寧に整えると相手に安心感を与えられます。',
      ],
      icon: Icons.verified_user,
      gradient: const [Color(0xFF00416A), Color(0xFFE4E5E6)],
    ),
  ];

  Future<void> _finish() async {
    await _storage.write(key: 'onboarding_done', value: '1');
    if (!mounted) return;
    if (widget.returnToCaller && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  double get _progress => (_index + 1) / _steps.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, index) => _OnboardingSlide(
                  step: _steps[index],
                  isCurrent: index == _index,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: AppColors.outline.withOpacity(0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: const Text('あとで設定する'),
                      ),
                      Expanded(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _steps.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                width: i == _index ? 22 : 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: i == _index
                                      ? theme.colorScheme.secondary
                                      : AppColors.outline,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: () async {
                          if (_index < _steps.length - 1) {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            await _finish();
                          }
                        },
                        child: Text(_index < _steps.length - 1 ? '次へ' : 'はじめる'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: _index == _steps.length - 1 ? 1 : 0.8,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '設定 > 通知 でアプリ内通知をオンにしておくと、再会したときにすぐ気付けます。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.step, required this.isCurrent});

  final _OnboardingStep step;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutQuint,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: step.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(26, 36, 26, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: isCurrent ? 1 : 0.8),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withOpacity(0.18),
                    child: Icon(step.icon, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              step.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withOpacity(0.92),
              ),
            ),
            const SizedBox(height: 24),
            ...step.tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Campus Connect',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
