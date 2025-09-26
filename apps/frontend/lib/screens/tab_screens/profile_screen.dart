import 'package:flutter/material.dart';
import '../ble_scan_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('プロフィール画面'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BleScanScreen(),
                  ),
                );
              },
              child: const Text('BLEスキャン (v0)'),
            ),
          ],
        ),
      ),
    );
  }
}
