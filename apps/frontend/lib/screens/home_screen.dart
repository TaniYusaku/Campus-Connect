import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/announcement_provider.dart';
import 'package:frontend/providers/in_app_notification_provider.dart';
import 'package:frontend/providers/notification_preferences_provider.dart';
import 'package:frontend/providers/recent_match_provider.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/screens/notification_history_screen.dart';
import 'package:frontend/screens/tab_screens/encounter_screen.dart';
import 'package:frontend/screens/tab_screens/friends_list_screen.dart';
import 'package:frontend/screens/tab_screens/profile_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/screens/announcements_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  Set<String> _knownFriendIds = <String>{};
  bool _friendBaselineReady = false;

  static const List<Widget> _widgetOptions = <Widget>[
    EncounterScreen(),
    FriendsListScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(announcementBadgeProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<User>>>(
      friendsFutureProvider,
      (previous, next) {
        if (!next.hasValue) return;
        final friends = next.value ?? [];
        final currentIds = friends.map((u) => u.id).toSet();
        if (!_friendBaselineReady) {
          _friendBaselineReady = true;
          _knownFriendIds = currentIds;
          return;
        }
        final newIds = currentIds.difference(_knownFriendIds);
        if (newIds.isEmpty) {
          _knownFriendIds = currentIds;
          return;
        }
        final notificationsEnabled = ref.read(notificationPreferenceProvider);
        if (notificationsEnabled) {
          final suppress = ref.read(recentlyCelebratedMatchesProvider);
          final notifier = ref.read(inAppNotificationProvider.notifier);
          for (final id in newIds) {
            if (suppress.contains(id)) {
              ref.read(recentlyCelebratedMatchesProvider.notifier).update((state) {
                final nextState = {...state}..remove(id);
                return nextState;
              });
              continue;
            }
            final user = friends.firstWhere((u) => u.id == id);
            notifier.show(
              title: '${user.username}さんと友達になりました',
              message: 'プロフィールからSNSをチェックしてみましょう。',
              category: NotificationCategory.newFriend,
            );
          }
        }
        _knownFriendIds = currentIds;
      },
    );
    final hasUnreadAnnouncements = ref.watch(announcementBadgeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Connect'),
        automaticallyImplyLeading: false,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.campaign_outlined),
                tooltip: 'お知らせ',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AnnouncementsScreen(),
                    ),
                  );
                },
              ),
              if (hasUnreadAnnouncements)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: _NotificationDot(),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            tooltip: '通知履歴',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _widgetOptions),
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

class _NotificationDot extends StatelessWidget {
  const _NotificationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.6),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
