import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/ble_provider.dart';
import '../providers/ble_advertise_provider.dart';

class BleScanScreen extends ConsumerWidget {
  const BleScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bleScanProvider);
    final notifier = ref.read(bleScanProvider.notifier);
    final advState = ref.watch(bleAdvertiseProvider);
    final advNotifier = ref.read(bleAdvertiseProvider.notifier);
    final threshold = ref.watch(rssiThresholdProvider);

    final results = state.results
        .where((r) => r.rssi >= threshold)
        .toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(title: const Text('BLE Scan (v0)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Bluetooth: ${state.adapterState.name}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      state.scanning ? notifier.stopScan : notifier.startScan,
                  child: Text(state.scanning ? 'Stop' : 'Start'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: advState.advertising ? advNotifier.stop : advNotifier.start,
                  child: Text(advState.advertising ? 'Adv Stop' : 'Adv Start'),
                ),
              ],
            ),
          ),
          if (advState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                'Advertise error: ${advState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Text('RSSI >= '),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${threshold}dBm',
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: threshold.toDouble(),
            min: -100,
            max: 0,
            divisions: 100,
            label: '$threshold dBm',
            onChanged: (v) =>
                ref.read(rssiThresholdProvider.notifier).state = v.round(),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                final device = r.device;
                final ad = r.advertisementData;
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(ad.advName.isNotEmpty
                      ? ad.advName
                      : device.platformName.isNotEmpty
                          ? device.platformName
                          : device.remoteId.str),
                  subtitle: Text('RSSI: ${r.rssi}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on BluetoothAdapterState {
  String get name => toString().split('.').last;
}
