import Foundation
import CoreBluetooth
import Flutter

class BleManager: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    static let serviceUUID = CBUUID(string: "0000C0DE-0000-1000-8000-00805F9B34FB")
    static let channelName = "com.example.campusconnect/ble"
    static var tids: [String] = []
    static var currentTidIndex: Int = 0
    static var tidTimer: Timer?
    static var scanTimer: Timer?
    static var centralManager: CBCentralManager?
    static var peripheralManager: CBPeripheralManager?
    static var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: channelName + "/events", binaryMessenger: registrar.messenger())
        let instance = BleManager()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - FlutterPlugin
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startBleService":
            if let args = call.arguments as? [String: Any], let tids = args["tids"] as? [String] {
                BleManager.tids = tids
                BleManager.currentTidIndex = 0
                self.startAdvertising()
                self.startScanning()
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
            }
        case "stopBleService":
            self.stopAdvertising()
            self.stopScanning()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Advertising
    func startAdvertising() {
        if BleManager.peripheralManager == nil {
            BleManager.peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        self.updateAdvertisingTid()
        BleManager.tidTimer?.invalidate()
        BleManager.tidTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            BleManager.currentTidIndex = (BleManager.currentTidIndex + 1) % BleManager.tids.count
            self.updateAdvertisingTid()
        }
    }

    func stopAdvertising() {
        BleManager.peripheralManager?.stopAdvertising()
        BleManager.tidTimer?.invalidate()
    }

    func updateAdvertisingTid() {
        guard !BleManager.tids.isEmpty else { return }
        let tid = BleManager.tids[BleManager.currentTidIndex]
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [BleManager.serviceUUID],
            CBAdvertisementDataServiceDataKey: [BleManager.serviceUUID: tid.data(using: .utf8) ?? Data()]
        ]
        BleManager.peripheralManager?.stopAdvertising()
        BleManager.peripheralManager?.startAdvertising(advertisementData)
    }

    // MARK: - Scanning
    func startScanning() {
        if BleManager.centralManager == nil {
            BleManager.centralManager = CBCentralManager(delegate: self, queue: nil)
        }
        self.scheduleScan()
    }

    func stopScanning() {
        BleManager.centralManager?.stopScan()
        BleManager.scanTimer?.invalidate()
    }

    func scheduleScan() {
        BleManager.scanTimer?.invalidate()
        BleManager.scanTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { _ in
            self.performScan()
        }
        self.performScan()
    }

    func performScan() {
        BleManager.centralManager?.scanForPeripherals(withServices: [BleManager.serviceUUID], options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            BleManager.centralManager?.stopScan()
            // スキャン結果をeventSinkで送信（ダミー実装）
            let dummyResult: [[String: Any]] = []
            BleManager.eventSink?(dummyResult)
        }
    }

    // MARK: - CBCentralManagerDelegate, CBPeripheralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {}
}

extension BleManager: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        BleManager.eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        BleManager.eventSink = nil
        return nil
    }
} 