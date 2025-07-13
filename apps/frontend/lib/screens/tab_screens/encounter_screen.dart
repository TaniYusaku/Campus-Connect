import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_connect_app/providers/encounter_provider.dart';

class EncounterScreen extends ConsumerWidget {
  const EncounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounters = ref.watch(encounterListProvider);

    return Scaffold(
      body: encounters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('エラー: $err')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('まだ誰もすれ違っていません。'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(user.username),
                subtitle: Text('${user.faculty} ${user.grade}年'),
              );
            },
          );
        },
      ),
    );
  }
} 