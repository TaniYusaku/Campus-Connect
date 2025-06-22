import 'dart:async';
import 'package:flutter/services.dart';

class BleService {
  static const MethodChannel _channel = MethodChannel('com.example.campusconnect/ble');
  static const EventChannel _eventChannel = EventChannel('com.example.campusconnect/ble/events');

  static Future<void> startBleService(List<String> tids) async {
    await _channel.invokeMethod('startBleService', {'tids': tids});
  }

  static Future<void> stopBleService() async {
    await _channel.invokeMethod('stopBleService');
  }

  static Stream<List<Map<String, dynamic>>> onTidsScanned() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is List) {
        return event.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return <Map<String, dynamic>>[];
    });
  }

  static void onScanResult(void Function(List<Map<String, dynamic>>) handler) {
    onTidsScanned().listen(handler);
  }
} 