import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/providers/encounter_provider.dart';

class EncounterScreen extends ConsumerWidget {
  const EncounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounterState = ref.watch(encounterProvider);

    return Scaffold(
      body: _buildBody(context, ref, encounterState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, EncounterState state) {
    if (state.isLoading && state.encounters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(child: Text('エラー: ${state.errorMessage}'));
    }

    if (state.encounters.isEmpty) {
      return const Center(
        child: Text(
          'まだ誰もすれ違っていません。\nすれ違い機能をオンにして、他のユーザーとすれ違ってみましょう！',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(encounterProvider.notifier).fetchEncounters(),
      child: ListView.builder(
        itemCount: state.encounters.length,
        itemBuilder: (context, index) {
          final user = state.encounters[index];
          return ListTile(
            leading: CircleAvatar(
              // TODO: ユーザー画像があれば表示
              child: Text(user.username.substring(0, 1)),
            ),
            title: Text(user.username),
            subtitle: Text('${user.faculty} ${user.grade}年'),
            // TODO: タップしたらプロフィール詳細画面に遷移
            onTap: () {},
          );
        },
      ),
    );
  }
} 