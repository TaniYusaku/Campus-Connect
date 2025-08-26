import Foundation
import CoreBluetooth

class BleService: NSObject, CBCentralManagerDelegate, CBPeripheralManagerDelegate {
    // CentralManagerとPeripheralManagerのインスタンス
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!

    // Flutterにイベントを送信するためのEventSink
    // AppDelegateに定義されたStreamHandlerから設定される
    var deviceFoundEventSink: FlutterEventSink?
    var bleStateEventSink: FlutterEventSink?

    // シングルトンインスタンス
    static let shared = BleService()

    // アプリ固有のサービスUUID
    private let serviceUUID = CBUUID(string: "00001234-0000-1000-8000-00805F9B34FB")
    
    // アドバタイズ/スキャンが有効かどうかの状態
    private var isStarted = false
    // 自分の一時ID
    private var currentTempId: String?

    private override init() {
        super.init()
        // デリゲートメソッドがメインスレッドで呼ばれるように、queueにnilを渡す
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // サービス開始
    func start(tempId: String) {
        print("BleService: start called with tempId: \(tempId)")
        self.isStarted = true
        self.currentTempId = tempId
        // 状態更新デリゲートが呼ばれるので、そこでスキャン・アドバタイズが開始される
        // 明示的に呼ぶ必要はないが、既にPowerOnの場合は即時開始するために呼ぶ
        if centralManager.state == .poweredOn {
            startScanning()
        }
        if peripheralManager.state == .poweredOn {
            startAdvertising()
        }
    }

    // サービス停止
    func stop() {
        print("BleService: stop called")
        self.isStarted = false
        self.currentTempId = nil
        stopScanning()
        stopAdvertising()
    }

    // スキャン開始
    private func startScanning() {
        guard centralManager.state == .poweredOn, isStarted else { return }
        print("BleService: Starting scan...")
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: options)
    }

    // スキャン停止
    private func stopScanning() {
        if centralManager.isScanning {
            print("BleService: Stopping scan.")
            centralManager.stopScan()
        }
    }

    // アドバタイズ開始
    private func startAdvertising() {
        guard peripheralManager.state == .poweredOn, let tempId = currentTempId, isStarted else { return }
        print("BleService: Starting advertising with tempId: \(tempId)")
        let serviceData = tempId.data(using: .utf8)
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataServiceDataKey: [serviceUUID: serviceData]
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    // アドバタイズ停止
    private func stopAdvertising() {
        if peripheralManager.isAdvertising {
            print("BleService: Stopping advertising.")
            peripheralManager.stopAdvertising()
        }
    }

    // 現在のBLE状態をFlutterに送信する
    func sendCurrentBleState() {
        guard let central = centralManager else { return }
        let stateStr: String
        switch central.state {
        case .poweredOn:
            stateStr = "poweredOn"
        case .poweredOff:
            stateStr = "poweredOff"
        case .unauthorized:
            stateStr = "unauthorized"
        default:
            stateStr = "unknown"
        }
        // メインスレッドから送信
        DispatchQueue.main.async {
            self.bleStateEventSink?(stateStr)
        }
    }

    // --- Delegateメソッド ---
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("BleService: CentralManager state updated to \(central.state.rawValue)")
        let stateStr: String
        switch central.state {
        case .poweredOn:
            stateStr = "poweredOn"
            startScanning()
        case .poweredOff:
            stateStr = "poweredOff"
        case .unauthorized:
            stateStr = "unauthorized"
        default:
            stateStr = "unknown"
        }
        // メインスレッドから送信
        DispatchQueue.main.async {
            self.bleStateEventSink?(stateStr)
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("BleService: PeripheralManager state updated to \(peripheral.state.rawValue)")
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard RSSI.intValue > -80 else { return }

        if let serviceData = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data],
           let tempIdData = serviceData[serviceUUID],
           let foundTempId = String(data: tempIdData, encoding: .utf8) {
            print("BleService: Discovered device with tempId: \(foundTempId) RSSI: \(RSSI)")
            // メインスレッドから送信
            DispatchQueue.main.async {
                self.deviceFoundEventSink?(foundTempId)
            }
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("BleService: Failed to start advertising: \(error.localizedDescription)")
        } else {
            print("BleService: Successfully started advertising.")
        }
    }
} 