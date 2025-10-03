import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/providers/encounter_provider.dart';
import '../ble_scan_screen.dart';

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
          return RefreshIndicator(
            onRefresh: () async {
              await ref.refresh(encounterListProvider.future);
            },
            child: users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 240),
                      Center(child: Text('まだ誰もすれ違っていません。')),
                    ],
                  )
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(user.username),
                        subtitle: Text('${user.faculty} ${user.grade}年'),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const BleScanScreen()))
              .then((_) {
            // BLEスキャン画面から戻ったら最新のすれ違いを再取得
            ref.invalidate(encounterListProvider);
          });
        },
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('BLEスキャン (v0)'),
      ),
    );
  }
} 
