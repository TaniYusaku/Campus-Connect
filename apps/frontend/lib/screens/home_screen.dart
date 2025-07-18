import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/providers/auth_provider.dart';
import 'package:campus_connect_app/screens/tab_screens/encounter_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/friends_list_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/profile_screen.dart';
import 'package:campus_connect_app/services/ble_coordinator_service.dart'; // インポート

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    EncounterScreen(),
    FriendsListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // initState内でrefを安全に使うために一手間加える
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // BLEサービスを開始
      ref.read(bleCoordinatorServiceProvider).start();
    });
  }

  @override
  void dispose() {
    // 画面が破棄される時にBLEサービスを停止
    ref.read(bleCoordinatorServiceProvider).stop();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'すれ違い',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: '友達',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'プロフィール',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
} 