import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // 1. Flutter -> Native の単発呼び出し用 MethodChannel
    let methodChannelName = "com.example.campus_connect/ble"
    let methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: controller.binaryMessenger)
    
    // 2. Native -> Flutter のイベント通知用 EventChannel
    let eventChannelName = "com.example.campus_connect/ble_events"
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: controller.binaryMessenger)
    
    // BleServiceをStreamHandlerとして設定
    eventChannel.setStreamHandler(BleService.shared)

    // MethodChannelの呼び出しハンドラを設定
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

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
