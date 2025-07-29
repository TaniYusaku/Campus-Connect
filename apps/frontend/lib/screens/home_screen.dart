import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/providers/auth_provider.dart';
import 'package:campus_connect_app/screens/tab_screens/encounter_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/friends_list_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/profile_screen.dart';
import 'package:campus_connect_app/services/ble_coordinator_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  // BLE権限がpermanentlyDeniedで設定画面に飛ばされたかどうかを管理する状態
  bool _userWasSentToSettings = false;

  static const List<Widget> _widgetOptions = <Widget>[
    EncounterScreen(),
    FriendsListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // userWasSentToSettingsNotifierの変更を監視
    ref.read(bleCoordinatorServiceProvider).userWasSentToSettingsNotifier.addListener(() {
      if (mounted) {
        setState(() {
          _userWasSentToSettings = ref.read(bleCoordinatorServiceProvider).userWasSentToSettingsNotifier.value;
        });
      }
    });

    // 初回起動時にBLEサービスを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBleServiceWithHandling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ref.read(bleCoordinatorServiceProvider).stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print("App resumed. Checking if BLE service needs to be restarted...");
      // userWasSentToSettingsがtrueの場合のみ、手動での再試行を促す
      if (_userWasSentToSettings) {
        // UIはそのまま（ボタンが表示されたまま）にする
        print("User was sent to settings, waiting for manual retry.");
      } else {
        // それ以外の場合は自動で再試行
        Future.delayed(const Duration(milliseconds: 500), () {
          _startBleServiceWithHandling();
        });
      }
    }
  }

  Future<void> _startBleServiceWithHandling() async {
    try {
      await ref.read(bleCoordinatorServiceProvider).start();
      // 成功した場合、_userWasSentToSettingsをfalseに戻す
      if (mounted) {
        setState(() {
          _userWasSentToSettings = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すれ違い機能を開始しました！')),
      );
      print("成功：権限は許可されていました。メイン画面に遷移します。");
    } catch (e) {
      // 失敗した場合、_userWasSentToSettingsがtrueならUIはそのまま
      // falseならエラーメッセージを表示
      if (!_userWasSentToSettings) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('すれ違い機能の開始に失敗しました: ${e.toString()}')),
        );
      }
      print("失敗：すれ違い機能を開始できませんでした。エラー: ${e.toString()}");
    }
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
      body: _userWasSentToSettings
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '設定ありがとうございます。下のボタンを押して、すれちがいを開始してください。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _startBleServiceWithHandling,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      child: const Text('スキャンとアドバタイズを開始する'),
                    ),
                  ],
                ),
              ),
            )
          : IndexedStack(
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