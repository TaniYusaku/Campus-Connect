import 'package:flutter/services.dart';

// BLEの状態を表すenum
enum BleState {
  unknown,
  poweredOn,
  poweredOff,
  unauthorized,
}

class BleServiceInterface {
  // チャンネル名を定義
  static const _platform = MethodChannel('com.example.campus_connect/ble');
  // ネイティブからのイベントを受け取るためのストリームを定義
  static const _eventChannelDeviceFound = EventChannel('com.example.campus_connect/ble_events');
  static const _eventChannelBleState = EventChannel('com.example.campus_connect/ble/onBleStateChanged');

  /// ネイティブのBLEサービスを開始する
  Future<void> startBleService(String tempId) async {
    try {
      await _platform.invokeMethod('startBleService', {'tempId': tempId});
    } on PlatformException catch (e) {
      // エラーハンドリング
      print("Failed to start BLE service: ' e.message'.");
    }
  }

  /// ネイティブのBLEサービスを停止する
  Future<void> stopBleService() async {
    try {
      await _platform.invokeMethod('stopBleService');
    } on PlatformException catch (e) {
      // エラーハンドリング
      print("Failed to stop BLE service: ' e.message'.");
    }
  }

  /// デバイス発見イベントのストリームを取得する
  Stream<String> get onDeviceFound {
    return _eventChannelDeviceFound.receiveBroadcastStream().cast<String>();
  }

  /// BLE状態変更イベントのストリームを取得する
  Stream<BleState> get onBleStateChanged {
     return _eventChannelBleState.receiveBroadcastStream().map((dynamic state) {
        switch (state as String) {
            case 'poweredOn':
                return BleState.poweredOn;
            case 'poweredOff':
                return BleState.poweredOff;
            case 'unauthorized':
                return BleState.unauthorized;
            default:
                return BleState.unknown;
        }
    });
  }
} 