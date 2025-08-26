import Flutter
import UIKit
import CoreBluetooth
import Firebase

// --- EventChannel Stream Handlers ---

// DeviceFoundイベント用のStreamHandler
class DeviceFoundStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        BleService.shared.deviceFoundEventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        BleService.shared.deviceFoundEventSink = nil
        return nil
    }
}

// BleState変更イベント用のStreamHandler
class BleStateStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        BleService.shared.bleStateEventSink = events
        // 初期状態を通知するために現在の状態を即座に送信
        BleService.shared.sendCurrentBleState()
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        BleService.shared.bleStateEventSink = nil
        return nil
    }
}


@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure() // Firebaseの初期化
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // --- Channelのセットアップ ---
    setupMethodChannel(messenger: controller.binaryMessenger)
    setupEventChannels(messenger: controller.binaryMessenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MethodChannelのセットアップ
  private func setupMethodChannel(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(name: "com.example.campus_connect/ble",
                                             binaryMessenger: messenger)
    
    methodChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      switch call.method {
      case "startBleService":
        guard let args = call.arguments as? [String: Any],
              let tempId = args["tempId"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "tempId is required", details: nil))
          return
        }
        BleService.shared.start(tempId: tempId)
        result(nil)
      case "stopBleService":
        BleService.shared.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }

  // EventChannelのセットアップ
  private func setupEventChannels(messenger: FlutterBinaryMessenger) {
    // 1. DeviceFoundイベント用
    let deviceFoundChannel = FlutterEventChannel(name: "com.example.campus_connect/ble_events",
                                                 binaryMessenger: messenger)
    deviceFoundChannel.setStreamHandler(DeviceFoundStreamHandler())

    // 2. BleState変更イベント用
    let bleStateChannel = FlutterEventChannel(name: "com.example.campus_connect/ble/onBleStateChanged",
                                              binaryMessenger: messenger)
    bleStateChannel.setStreamHandler(BleStateStreamHandler())
  }
}
