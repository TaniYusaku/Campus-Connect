import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'shared/app_theme.dart';
import 'widgets/in_app_notification_host.dart';
import 'screens/welcome_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/auth/auth_welcome_screen.dart';
import 'screens/privacy_policy_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ← Firebase前に必要

  await Firebase.initializeApp(); // ← シンプル初期化（GoogleService-Info.plistを読み込む）

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Campus Connect',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: LaunchGate(authState: authState),
    );
  }
}

class LaunchGate extends StatefulWidget {
  final AuthState authState;

  const LaunchGate({super.key, required this.authState});

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  static const _welcomeKey = 'welcome_seen';
  static const _termsKey = 'terms_accepted';
  static const _privacyKey = 'privacy_policy_seen';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _loadingPrefs = true;
  bool _welcomeSeen = false;
  bool _termsAccepted = false;
  bool _privacySeen = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final welcome = await _storage.read(key: _welcomeKey);
    final terms = await _storage.read(key: _termsKey);
    final privacy = await _storage.read(key: _privacyKey);
    if (!mounted) return;
    setState(() {
      _welcomeSeen = welcome == '1';
      _termsAccepted = terms == '1';
      _privacySeen = privacy == '1';
      _loadingPrefs = false;
    });
  }

  Future<void> _handleWelcomeContinue() async {
    await _storage.write(key: _welcomeKey, value: '1');
    if (!mounted) return;
    setState(() => _welcomeSeen = true);
  }

  Future<void> _handleTermsAccepted() async {
    await _storage.write(key: _termsKey, value: '1');
    if (!mounted) return;
    setState(() => _termsAccepted = true);
  }

  Future<void> _handlePrivacyAccepted() async {
    await _storage.write(key: _privacyKey, value: '1');
    if (!mounted) return;
    setState(() => _privacySeen = true);
  }

  Widget _buildAuthEntry() {
    switch (widget.authState) {
      case AuthState.authenticated:
        return const _HomeGate();
      case AuthState.unauthenticated:
        return const AuthWelcomeScreen();
      case AuthState.checking:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPrefs || widget.authState == AuthState.checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.authState == AuthState.unauthenticated) {
      return const AuthWelcomeScreen();
    }

    if (!_welcomeSeen) {
      return WelcomeScreen(onStartPressed: _handleWelcomeContinue);
    }

    if (!_termsAccepted) {
      return TermsScreen(onAccepted: _handleTermsAccepted);
    }

    if (!_privacySeen) {
      return PrivacyPolicyScreen(
        onAccepted: _handlePrivacyAccepted,
        showConsent: true,
      );
    }

    return _buildAuthEntry();
  }
}

// Shows HomeScreen and, if onboarding not done, pushes Onboarding on top once.
class _HomeGate extends StatefulWidget {
  const _HomeGate();
  @override
  State<_HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<_HomeGate> {
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _maybeShowOnboarding();
  }

  Future<void> _maybeShowOnboarding() async {
    final storage = const FlutterSecureStorage();
    final done = await storage.read(key: 'onboarding_done');
    if (!mounted) return;
    if (done != '1' && !_pushed) {
      _pushed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const InAppNotificationHost(
      child: HomeScreen(),
    );
  }
}
