import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'providers/ble_advertise_provider.dart';
import 'screens/register_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    // Ensure auto-advertising manager is active regardless of current screen
    ref.watch(autoAdvertiseManagerProvider);

    Widget getHome() {
      switch (authState) {
        case AuthState.authenticated:
          return const _HomeGate();
        case AuthState.unauthenticated:
          return const RegisterScreen();
        case AuthState.checking:
        default:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
      }
    }

    return MaterialApp(
      title: 'Campus Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: getHome(),
    );
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
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
