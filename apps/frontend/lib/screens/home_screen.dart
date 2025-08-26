import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:campus_connect_app/providers/auth_provider.dart';
import 'package:campus_connect_app/providers/encounter_provider.dart';
import 'package:campus_connect_app/services/ble_coordinator_service.dart';
import 'package:campus_connect_app/services/ble_service_interface.dart'; // BleState enumのため
import 'package:campus_connect_app/screens/tab_screens/encounter_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/friends_list_screen.dart';
import 'package:campus_connect_app/screens/tab_screens/profile_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  // ユーザーが機能を有効にしているかどうかの設定値。SharedPreferencesで永続化する。
  bool _isEncounterServiceEnabled = true; 
  static const String _serviceStatusKey = 'isEncounterServiceActive';

  late final BleCoordinatorService _bleService;

  static const List<Widget> _widgetOptions = <Widget>[
    EncounterScreen(),
    FriendsListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _bleService = ref.read(bleCoordinatorServiceProvider);

    // 最初のフレームが描画された後に、BLEの自動開始処理を呼び出す
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServiceStatusAndStartIfNeeded();
    });

    _bleService.userWasSentToSettingsNotifier.addListener(_showOpenSettingsDialog);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _bleService.userWasSentToSettingsNotifier.removeListener(_showOpenSettingsDialog);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // ユーザーが機能を有効にしている場合のみ、権限を再チェックしてサービスを開始試行
      if (_isEncounterServiceEnabled) {
        print('App resumed, re-checking permissions and starting service if needed.');
        Future.delayed(const Duration(milliseconds: 500), () {
            _startEncounterServiceIfNeeded();
        });
      }
    }
  }

  // 永続化された設定を読み込み、必要であれば自動でサービスを開始する
  Future<void> _loadServiceStatusAndStartIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    // ユーザーが明示的にオフにしない限り、デフォルトは有効(true)
    final isEnabled = prefs.getBool(_serviceStatusKey) ?? true;
    
    setState(() {
      _isEncounterServiceEnabled = isEnabled;
    });

    if (isEnabled) {
      // 権限要求を含め、サービス開始を試みる
      _startEncounterServiceIfNeeded();
    }
  }

  // サービスの状態を永続化する
  Future<void> _saveServiceStatus(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_serviceStatusKey, isEnabled);
  }

  // UIからサービスを停止する際に呼ばれる
  void _onStopService() {
    _saveServiceStatus(false);
    setState(() {
      _isEncounterServiceEnabled = false;
    });
    _bleService.stop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('すれ違い機能を停止しました。')),
    );
  }

  // UIからサービスを開始する際に呼ばれる
  void _onStartService() {
    _saveServiceStatus(true);
    setState(() {
      _isEncounterServiceEnabled = true;
    });
    _startEncounterServiceIfNeeded();
  }

  // 権限要求とサービス開始のコアロジック
  Future<void> _startEncounterServiceIfNeeded() async {
    final bleState = _bleService.bleStateNotifier.value;
    if (bleState != BleState.poweredOn) {
      // 起動時の自動開始でBluetoothがオフの場合、ユーザーに通知は不要かもしれない
      print('Cannot start service: Bluetooth is not powered on.');
      return;
    }

    final bool permissionsGranted = await _bleService.requestPermissions();

    if (!permissionsGranted) {
      if (!_bleService.userWasSentToSettingsNotifier.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetoothの権限が許可されなかったため、開始できません。')),
        );
      }
      // 権限が得られなかったら、機能を無効として設定を保存
      await _saveServiceStatus(false);
      setState(() { _isEncounterServiceEnabled = false; });
      return;
    }

    try {
      await _bleService.start();
      // サービスが正常に開始されたことを確認
      print("Service successfully started.");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーにより開始できませんでした: $e')),
      );
      // エラーが発生した場合も機能を無効として設定を保存
      await _saveServiceStatus(false);
      setState(() { _isEncounterServiceEnabled = false; });
    }
  }

  void _showOpenSettingsDialog() {
    if (_bleService.userWasSentToSettingsNotifier.value) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bluetoothの権限が必要です'),
          content: const Text('すれ違い機能を利用するには、設定アプリでBluetoothの権限を許可してください。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('設定を開く'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      _bleService.userWasSentToSettingsNotifier.value = false;
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleService = ref.watch(bleCoordinatorServiceProvider);

    ref.listen(encounterProvider, (previous, next) {
      if (next.errorMessage == null && (previous != null && next.encounters.length > previous.encounters.length)) {
        final newUser = next.encounters.first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newUser.username}さんとすれ違いました！'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    final List<Widget> screens = [
      ValueListenableBuilder<BleState>(
        valueListenable: bleService.bleStateNotifier,
        builder: (context, bleState, child) {
          return ValueListenableBuilder<bool>(
            valueListenable: bleService.isServiceRunningNotifier,
            builder: (context, isRunning, child) {
              return EncounterControlPanel(
                isEnabled: _isEncounterServiceEnabled,
                onStart: _onStartService,
                onStop: _onStopService,
                bleState: bleState,
                isServiceRunning: isRunning,
              );
            },
          );
        },
      ),
      const FriendsListScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'すれ違い'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: '友達'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'プロフィール'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// UIを管理する新しいウィジェット
class EncounterControlPanel extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final BleState bleState;
  final bool isServiceRunning;

  const EncounterControlPanel({
    super.key,
    required this.isEnabled,
    required this.onStart,
    required this.onStop,
    required this.bleState,
    required this.isServiceRunning,
  });

  // 状態に応じたステータステキストとアイコンを生成する
  Widget _buildStatus(BuildContext context) {
    final theme = Theme.of(context);

    if (!isEnabled) {
      return Row(
        children: [
          const Icon(Icons.bluetooth_disabled, color: Colors.grey),
          const SizedBox(width: 8),
          Text('すれ違い機能は停止中です', style: theme.textTheme.bodyLarge),
        ],
      );
    }

    // isEnabled が true の場合
    if (isServiceRunning) {
      return Row(
        children: [
          const Icon(Icons.bluetooth_searching, color: Colors.blue),
          const SizedBox(width: 8),
          Text('すれ違い通信中', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.blue)),
        ],
      );
    }
    
    switch (bleState) {
      case BleState.poweredOn:
        return Row(
          children: [
            const Icon(Icons.bluetooth, color: Colors.grey),
            const SizedBox(width: 8),
            Text('すれ違いの準備ができました', style: theme.textTheme.bodyLarge),
          ],
        );
      case BleState.poweredOff:
        return Row(
          children: [
            const Icon(Icons.bluetooth_disabled, color: Colors.red),
            const SizedBox(width: 8),
            Text('Bluetoothをオンにしてください', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red)),
          ],
        );
      case BleState.unauthorized:
        return Row(
          children: [
            const Icon(Icons.block, color: Colors.red),
            const SizedBox(width: 8),
            Text('Bluetoothの権限がありません', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red)),
          ],
        );
      default:
        return Row(
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.0)),
            const SizedBox(width: 8),
            Text('BLEの状態を確認中です...', style: theme.textTheme.bodyLarge),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 左側にステータス
              _buildStatus(context),
              // 右側にボタン
              isEnabled
                  ? OutlinedButton(onPressed: onStop, child: const Text('停止'))
                  : ElevatedButton(onPressed: onStart, child: const Text('再開')),
            ],
          ),
        ),
        const Divider(),
        const Expanded(
          child: EncounterScreen(), // すれ違いユーザーリスト
        ),
      ],
    );
  }
} 