import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/models/user.dart';
import 'package:frontend/providers/api_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/ble_advertise_provider.dart';
import 'package:frontend/providers/ble_provider.dart';
import 'package:frontend/providers/encounter_provider.dart';
import 'package:frontend/providers/in_app_notification_provider.dart';
import 'package:frontend/providers/like_provider.dart';
import 'package:frontend/providers/liked_history_provider.dart';
import 'package:frontend/providers/notification_preferences_provider.dart';
import 'package:frontend/providers/recent_match_provider.dart';
import 'package:frontend/screens/public_profile_screen.dart';
import 'package:frontend/screens/tab_screens/friends_list_screen.dart';
import 'package:frontend/shared/app_theme.dart';

const _activeScanGradient = LinearGradient(
  colors: [
    Color(0xFF1760C5),
    Color(0xFF4CB5FF),
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class EncounterScreen extends ConsumerStatefulWidget {
  const EncounterScreen({super.key});

  @override
  ConsumerState<EncounterScreen> createState() => _EncounterScreenState();
}

enum _GenderFilter { all, male, female }

class _EncounterScreenState extends ConsumerState<EncounterScreen>
    with TickerProviderStateMixin {
  bool _toggling = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _pulseActive = false;
  late final TabController _tabController;
  final FlutterSecureStorage _uiStorage = const FlutterSecureStorage();
  static const String _tabStorageKey = 'ui_encounter_tab_index';
  final Map<String, DateTime?> _lastEncounteredAtMap = {};
  final Map<String, int> _encounterCountMap = {};
  final Map<String, bool> _isFriendMap = {};
  Timer? _autoRefreshTimer;
  bool _encounterBaselineReady = false;
  _GenderFilter _genderFilter = _GenderFilter.all;
  bool _sameFacultyOnly = false;
  bool _sameGradeOnly = false;
  bool _filterExpanded = false;

  Future<void> _toggleScanAndAdvertise(bool running) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final scanNotifier = ref.read(bleScanProvider.notifier);
    final advNotifier = ref.read(bleAdvertiseProvider.notifier);
    final continuous = ref.read(continuousScanProvider.notifier);
    try {
      if (running) {
        await scanNotifier.stopScan();
        await advNotifier.stop();
        await continuous.set(false);
      } else {
        await continuous.set(true);
        try {
          await advNotifier.start();
        } catch (e) {
          await continuous.set(false);
          rethrow;
        }
        try {
          await scanNotifier.startScan();
        } catch (e) {
          await scanNotifier.stopScan();
          await advNotifier.stop();
          await continuous.set(false);
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('BLEの開始/停止に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _restoreTabIndex();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    _uiStorage.write(key: _tabStorageKey, value: _tabController.index.toString());
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(encounterListProvider);
      ref.invalidate(friendsFutureProvider);
    });
  }

  String _formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) {
      return '時刻情報なし';
    }
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'たった今';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}時間前';
    }
    return '${diff.inDays}日前';
  }

  String _gradeLabel(int? grade) {
    if (grade == null) return '学年未設定';
    switch (grade) {
      case 5:
        return 'M1';
      case 6:
        return 'M2';
      default:
        return '${grade}年';
    }
  }

  List<User> _filterByGender(List<User> users) {
    switch (_genderFilter) {
      case _GenderFilter.all:
        return users;
      case _GenderFilter.male:
        return users.where((u) => u.gender == '男性').toList();
      case _GenderFilter.female:
        return users.where((u) => u.gender == '女性').toList();
    }
  }

  List<User> _filterByFaculty(List<User> users, User? me) {
    if (!_sameFacultyOnly || me?.faculty == null) return users;
    return users.where((u) => u.faculty == me?.faculty).toList();
  }

  List<User> _filterByGrade(List<User> users, User? me) {
    if (!_sameGradeOnly || me?.grade == null) return users;
    return users.where((u) => u.grade == me?.grade).toList();
  }

  String _buildFilterSummary() {
    final genderLabel = switch (_genderFilter) {
      _GenderFilter.all => 'すべて',
      _GenderFilter.male => '男性',
      _GenderFilter.female => '女性',
    };
    final conditions = <String>[];
    if (_sameFacultyOnly) {
      conditions.add('同じ学部だけ');
    }
    if (_sameGradeOnly) {
      conditions.add('同じ学年だけ');
    }
    final conditionLabel = conditions.isEmpty ? 'なし' : conditions.join('・');
    return '性別: $genderLabel / 条件: $conditionLabel';
  }

  Future<void> _restoreTabIndex() async {
    final stored = await _uiStorage.read(key: _tabStorageKey);
    final index = int.tryParse(stored ?? '0');
    if (!mounted) return;
    if (index != null && index >= 0 && index < _tabController.length) {
      _tabController.index = index;
    }
  }

  void _handleEncounterNotifications(List<User> users) {
    final notificationsEnabled = ref.read(notificationPreferenceProvider);
    final notifier = notificationsEnabled
        ? ref.read(inAppNotificationProvider.notifier)
        : null;

    final currentIds = <String>{};
    for (final user in users) {
      currentIds.add(user.id);
      final latest = user.lastEncounteredAt;
      final previous = _lastEncounteredAtMap[user.id];
      final hasNewEncounter =
          latest != null && (previous == null || latest.isAfter(previous));
      final currentCount = user.encounterCount;
      final previousCount = _encounterCountMap[user.id] ?? 0;

      final wasFriend = _isFriendMap[user.id] ?? false;
      final isFriendNow = user.isFriend;
      final becameFriend = isFriendNow && !wasFriend;

      if (notificationsEnabled && hasNewEncounter) {
        if (isFriendNow) {
          notifier?.show(
            title: '友達の${user.username}さんと再会！',
            message: 'アプリで繋がりを確認して声をかけてみましょう。',
            category: NotificationCategory.friendEncounter,
          );
        } else if (currentCount >= 2 && previousCount < currentCount) {
          notifier?.show(
            title: '${user.username}さんと$currentCount回すれ違っています',
            message: 'よく会う相手には思い切っていいねしてみましょう。',
            category: NotificationCategory.repeatEncounter,
          );
        }
      }

      if (becameFriend) {
        ref.invalidate(friendsFutureProvider);
      }

      _lastEncounteredAtMap[user.id] = latest ?? previous;
      _encounterCountMap[user.id] = currentCount;
      _isFriendMap[user.id] = isFriendNow;
    }

    _lastEncounteredAtMap.removeWhere((key, _) => !currentIds.contains(key));
    _encounterCountMap.removeWhere((key, _) => !currentIds.contains(key));
    _isFriendMap.removeWhere((key, _) => !currentIds.contains(key));
  }

  Future<void> _showMatchCelebration(User user) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.softGold,
                AppColors.primaryNavy.withValues(alpha: 0.92),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withValues(alpha: 0.25),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1.0),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
                child: const Icon(
                  Icons.celebration,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '友達になりました！',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${user.username} さんと再会したらメッセージを送ってみましょう。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FriendsListScreen(showBack: true),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryNavy,
                ),
                child: const Text('友達リストを開く'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<User>>>(
      encounterListProvider,
      (previous, next) {
        if (!next.hasValue) return;
        final users = next.value ?? [];
        if (!_encounterBaselineReady) {
          for (final user in users) {
            _lastEncounteredAtMap[user.id] = user.lastEncounteredAt;
            _encounterCountMap[user.id] = user.encounterCount;
            _isFriendMap[user.id] = user.isFriend;
          }
          _encounterBaselineReady = true;
          return;
        }
        _handleEncounterNotifications(users);
      },
    );
    final encounterAsync = ref.watch(encounterListProvider);
    final myProfileAsync = ref.watch(profileProvider);
    final myProfile = myProfileAsync.maybeWhen(data: (value) => value, orElse: () => null);
    final likedHistory = ref.watch(likedHistoryProvider);
    final likedSet = ref.watch(likedSetProvider);
    final scanState = ref.watch(bleScanProvider);
    final advState = ref.watch(bleAdvertiseProvider);
    final friendIds = ref.watch(friendsFutureProvider).maybeWhen(
          data: (friends) => friends.map((u) => u.id).toSet(),
          orElse: () => <String>{},
        );

    final running = scanState.scanning || advState.advertising;
    final buttonLabel = running ? 'すれ違いを停止' : 'すれ違いを開始';
    final buttonIcon = running ? Icons.stop_circle : Icons.play_arrow_rounded;
    final cardGradient = running
        ? _activeScanGradient
        : const LinearGradient(
            colors: [Color(0xFF1F2D3F), Color(0xFF3B4A63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    if (running && !_pulseActive) {
      _pulseController.repeat(reverse: true);
      _pulseActive = true;
    } else if (!running && _pulseActive) {
      _pulseController.stop();
      _pulseController.reset();
      _pulseActive = false;
    }

    Future<void> refreshEncounters() async {
      final _ = await ref.refresh(encounterListProvider.future);
      await ref.read(likedHistoryProvider.notifier).purgeExpired();
    }

    Future<void> refreshLikes() async {
      await ref.read(likedHistoryProvider.notifier).purgeExpired();
      final _ = await ref.refresh(encounterListProvider.future);
    }

    Widget buildEncounterTab() {
      return encounterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 200),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('エラー: $err'),
            ),
          ],
        ),
        data: (users) {
          final filtered = users
              .where((user) =>
                  !likedSet.contains(user.id) && !friendIds.contains(user.id))
              .toList();
          if (filtered.isEmpty) {
            return RefreshIndicator(
              onRefresh: refreshEncounters,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('まだ誰もすれ違っていません。')),
                ],
              ),
            );
          }
          final genderFiltered = _filterByGender(filtered);
          final facultyFiltered = _filterByFaculty(genderFiltered, myProfile);
          final gradeFiltered = _filterByGrade(facultyFiltered, myProfile);
          if (gradeFiltered.isEmpty) {
            return RefreshIndicator(
              onRefresh: refreshEncounters,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('この条件に当てはまる相手はいません。')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refreshEncounters,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: gradeFiltered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final user = gradeFiltered[index];
                final isLiked = likedSet.contains(user.id);
                final lastSeenText = _formatRelativeTime(user.lastEncounteredAt);
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.paleGold,
                      child: Text(
                        user.username.characters.first,
                        style: const TextStyle(
                          color: AppColors.primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.username),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _InfoChip(label: user.faculty ?? '学部未設定'),
                            _InfoChip(label: _gradeLabel(user.grade)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '最終すれ違い: $lastSeenText',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(
                            userId: user.id,
                            initialUser: user,
                          ),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: isLiked ? 'いいねを取り消す' : 'いいね',
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.pink : null,
                          ),
                          onPressed: () async {
                          final api = ref.read(apiServiceProvider);
                          if (!isLiked) {
                            final res = await api.likeUser(user.id);
                            if (!mounted) return;
                            if (!res.ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('いいねに失敗しました')),
                              );
                              return;
                            }
                            ref.invalidate(encounterListProvider);
                            if (res.matchCreated) {
                            ref.invalidate(friendsFutureProvider);
                            ref.read(likedSetProvider.notifier).unmark(user.id);
                            await ref
                                .read(likedHistoryProvider.notifier)
                                .removeByUserId(user.id);
                              ref
                                  .read(recentlyCelebratedMatchesProvider.notifier)
                                  .update((state) => {...state, user.id});
                              if (mounted) {
                                await _showMatchCelebration(user);
                              }
                            } else {
                              ref.read(likedSetProvider.notifier).markLiked(user.id);
                              await ref
                                  .read(likedHistoryProvider.notifier)
                                  .addFromUser(user);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('いいねしました')),
                                );
                                _tabController.animateTo(1);
                              }
                            }
                          } else {
                            final ok = await api.unlikeUser(user.id);
                            if (!mounted) return;
                            if (ok) {
                              ref.read(likedSetProvider.notifier).unmark(user.id);
                              await ref
                                  .read(likedHistoryProvider.notifier)
                                  .removeByUserId(user.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('いいねを取り消しました')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '取り消せませんでした（友達になっている場合はブロックをご利用ください）',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                        IconButton(
                          tooltip: 'ブロック',
                          icon: const Icon(Icons.block),
                          onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('ブロックしますか？'),
                              content: Text(
                                '${user.username} をブロックします。以降すれ違い/友達に表示されません。',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('ブロック'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          final api = ref.read(apiServiceProvider);
                          final ok = await api.blockUser(user.id);
                          if (!mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ブロックしました')),
                            );
                            ref.invalidate(encounterListProvider);
                            ref.invalidate(friendsFutureProvider);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ブロックに失敗しました')),
                            );
                          }
                        },
                      ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    bool _matchesGenderFilter(String? gender) {
      switch (_genderFilter) {
        case _GenderFilter.all:
          return true;
        case _GenderFilter.male:
          return gender == '男性';
        case _GenderFilter.female:
          return gender == '女性';
      }
    }

    bool _matchesFacultyFilter(String? faculty) {
      if (!_sameFacultyOnly) return true;
      final myFaculty = myProfile?.faculty;
      if (myFaculty == null) return false;
      return faculty == myFaculty;
    }

    bool _matchesGradeFilter(int? grade) {
      if (!_sameGradeOnly) return true;
      final myGrade = myProfile?.grade;
      if (myGrade == null) return false;
      return grade == myGrade;
    }

    Widget buildLikedTab() {
      final availableLikes = likedHistory
          .where((entry) => !friendIds.contains(entry.userId))
          .toList();
      final filteredLikes = availableLikes
          .where((entry) => _matchesGenderFilter(entry.gender))
          .where((entry) => _matchesFacultyFilter(entry.faculty))
          .where((entry) => _matchesGradeFilter(entry.grade))
          .toList();
      if (filteredLikes.isEmpty) {
        final message = availableLikes.isEmpty
            ? '最近いいねしたユーザーはいません'
            : 'この条件に当てはまるいいね履歴はありません';
        return RefreshIndicator(
          onRefresh: refreshLikes,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 200),
              Center(child: Text(message)),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: refreshLikes,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: filteredLikes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = filteredLikes[index];
            final placeholderUser = User(
              id: entry.userId,
              username: entry.username,
              faculty: entry.faculty,
              grade: entry.grade,
              email: null,
              bio: null,
              profilePhotoUrl: null,
              snsLinks: null,
              gender: null,
            );
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentCrimson.withValues(alpha: 0.12),
                  child: const Icon(Icons.favorite, color: AppColors.accentCrimson),
                ),
                title: Text(entry.username),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      '${entry.faculty ?? '学部未設定'} ${_gradeLabel(entry.grade)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(
                        userId: entry.userId,
                        initialUser: placeholderUser,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  tooltip: 'いいねを取り消す',
                  icon: const Icon(Icons.cancel, color: AppColors.accentCrimson),
                  onPressed: () async {
                    final api = ref.read(apiServiceProvider);
                    final ok = await api.unlikeUser(entry.userId);
                    if (!mounted) return;
                    if (ok) {
                      ref.read(likedSetProvider.notifier).unmark(entry.userId);
                    await ref
                        .read(likedHistoryProvider.notifier)
                        .removeByUserId(entry.userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('いいねを取り消しました')),
                    );
                    await refreshEncounters();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('取り消せませんでした')),
                    );
                    }
                  },
                ),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: cardGradient,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ScanPulseIndicator(
                          running: running,
                          animation: _pulseAnimation,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            running ? 'スキャン中' : 'スキャン停止中',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          _toggling ? null : () => _toggleScanAndAdvertise(running),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(buttonIcon),
                      label: Text(_toggling ? '処理中...' : buttonLabel),
                    ),
                    const SizedBox(height: 6),
                    AnimatedOpacity(
                      opacity: running ? 1 : 0.7,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        '検知範囲はおよそ5〜10mです。',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                    if (advState.error != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '広告エラー: ${advState.error}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.red[100]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'すれ違い'),
                Tab(text: 'いいね'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _FilterBar(
                summary: _buildFilterSummary(),
                expanded: _filterExpanded,
                onTap: () => setState(() {
                  _filterExpanded = !_filterExpanded;
                }),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _EncounterFilterPanel(
                  selectedGender: _genderFilter,
                  onGenderSelected: (filter) {
                    if (_genderFilter == filter) return;
                    setState(() => _genderFilter = filter);
                  },
                  sameFacultyOnly: _sameFacultyOnly,
                  sameGradeOnly: _sameGradeOnly,
                  onChangedFaculty: (value) =>
                      setState(() => _sameFacultyOnly = value),
                  onChangedGrade:
                      (value) => setState(() => _sameGradeOnly = value),
                ),
              ),
              crossFadeState: _filterExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  buildEncounterTab(),
                  buildLikedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.summary,
    required this.expanded,
    required this.onTap,
  });

  final String summary;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrowIcon = expanded ? Icons.expand_less : Icons.expand_more;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.filter_alt),
              const SizedBox(width: 8),
              Text(
                '絞り込み',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(arrowIcon),
            ],
          ),
        ),
      ),
    );
  }
}

class _EncounterFilterPanel extends StatelessWidget {
  const _EncounterFilterPanel({
    required this.selectedGender,
    required this.onGenderSelected,
    required this.sameFacultyOnly,
    required this.sameGradeOnly,
    required this.onChangedFaculty,
    required this.onChangedGrade,
  });

  final _GenderFilter selectedGender;
  final ValueChanged<_GenderFilter> onGenderSelected;
  final bool sameFacultyOnly;
  final bool sameGradeOnly;
  final ValueChanged<bool> onChangedFaculty;
  final ValueChanged<bool> onChangedGrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GenderFilterSection(
          selected: selectedGender,
          onSelected: onGenderSelected,
        ),
        const SizedBox(height: 12),
        _ConditionFilterSection(
          sameFacultyOnly: sameFacultyOnly,
          sameGradeOnly: sameGradeOnly,
          onChangedFaculty: onChangedFaculty,
          onChangedGrade: onChangedGrade,
        ),
      ],
    );
  }
}

class _GenderFilterSection extends StatelessWidget {
  const _GenderFilterSection({
    required this.selected,
    required this.onSelected,
  });

  final _GenderFilter selected;
  final ValueChanged<_GenderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _buildChip(context, _GenderFilter.all, 'すべて'),
      _buildChip(context, _GenderFilter.male, '男性'),
      _buildChip(context, _GenderFilter.female, '女性'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性別で絞り込み',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: chips,
        ),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context,
    _GenderFilter filter,
    String label,
  ) {
    final isSelected = selected == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(filter),
    );
  }
}

class _ConditionFilterSection extends StatelessWidget {
  const _ConditionFilterSection({
    required this.sameFacultyOnly,
    required this.sameGradeOnly,
    required this.onChangedFaculty,
    required this.onChangedGrade,
  });

  final bool sameFacultyOnly;
  final bool sameGradeOnly;
  final ValueChanged<bool> onChangedFaculty;
  final ValueChanged<bool> onChangedGrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '条件で絞り込み',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('同じ学部だけ'),
              selected: sameFacultyOnly,
              onSelected: onChangedFaculty,
            ),
            FilterChip(
              label: const Text('同じ学年だけ'),
              selected: sameGradeOnly,
              onSelected: onChangedGrade,
            ),
          ],
        ),
      ],
    );
  }
}

class _ScanPulseIndicator extends StatelessWidget {
  const _ScanPulseIndicator({required this.running, required this.animation});

  final bool running;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: running
            ? AppColors.softGold.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.18),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        running ? Icons.wifi_tethering : Icons.bluetooth_searching,
        color: Colors.white,
        size: 28,
      ),
    );

    if (!running) {
      return circle;
    }

    return ScaleTransition(
      scale: animation,
      child: circle,
    );
  }
}
