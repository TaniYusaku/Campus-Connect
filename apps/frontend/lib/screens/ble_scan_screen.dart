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

    final results =
        state.results.where((r) => r.rssi >= threshold).toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(title: const Text('BLE Scan (v0)')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bluetooth: ${state.adapterState.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Continuous'),
                        const SizedBox(width: 6),
                        Consumer(
                          builder: (context, ref, _) {
                            final on = ref.watch(continuousScanProvider);
                            return Switch(
                              value: on,
                              onChanged:
                                  (v) => ref
                                      .read(continuousScanProvider.notifier)
                                      .set(v),
                            );
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('CC only'),
                        const SizedBox(width: 6),
                        Consumer(
                          builder: (context, ref, _) {
                            final ccOnly = ref.watch(ccFilterProvider);
                            return Switch(
                              value: ccOnly,
                              onChanged:
                                  (v) => ref
                                      .read(ccFilterProvider.notifier)
                                      .set(v),
                            );
                          },
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed:
                          state.scanning
                              ? notifier.stopScan
                              : notifier.startScan,
                      child: Text(state.scanning ? 'Stop' : 'Start'),
                    ),
                    ElevatedButton(
                      onPressed:
                          advState.advertising
                              ? advNotifier.stop
                              : advNotifier.start,
                      child: Text(
                        advState.advertising ? 'Adv Stop' : 'Adv Start',
                      ),
                    ),
                  ],
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
                  child: Text('${threshold}dBm', textAlign: TextAlign.right),
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
            onChanged:
                (v) => ref.read(rssiThresholdProvider.notifier).set(v.round()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final r = results[index];
                final device = r.device;
                final ad = r.advertisementData;
                final isCc = ad.advName.startsWith('CC-');
                final svcCount = ad.serviceUuids.length;
                final title =
                    ad.advName.isNotEmpty
                        ? ad.advName
                        : device.platformName.isNotEmpty
                        ? device.platformName
                        : device.remoteId.str;
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Row(
                    children: [
                      Expanded(child: Text(title)),
                      if (isCc)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'CC',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('RSSI: ${r.rssi}  • svcUUIDs: ${svcCount}'),
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
