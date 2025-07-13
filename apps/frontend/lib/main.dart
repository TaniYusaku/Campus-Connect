import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart'; // RegisterScreenの代わりにWelcomeScreenをインポート

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    Widget getHome() {
      switch (authState) {
        case AuthState.authenticated:
          return const HomeScreen();
        case AuthState.unauthenticated:
          return const WelcomeScreen(); // 未認証時はWelcomeScreenを表示
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
