import CoreBluetooth
import NearbyInteraction
import SwiftUI

let SERVICE_UUID = CBUUID(string: "0000180D-0000-1000-8000-00805F9B34FB")
let CHARACTERISTIC_UUID = CBUUID(string: "00002A37-0000-1000-8000-00805F9B34FB")

struct DiscoveredPeer {
    let token: NIDiscoveryToken
    let distance: Float
    let direction: SIMD3<Float>?
}

class HandsfreeUWB: NSObject, ObservableObject {
    private var _niSession: NISession!
    private var _peripheral: CBPeripheralManager!
    private var _central: CBCentralManager!
    private var _transferCharacteristic: CBMutableCharacteristic!
    private var connectionAttempts = 0
    private var scanInterval: TimeInterval = 60.0 // 60秒ごとにスキャンを再開する
    private var maxConnectionAttempts = 3

    @Published var discoveredPeers = [DiscoveredPeer]()
    @Published var peripherals = [CBPeripheral]()
    @Published var distance: Float = 0.0
    @Published var receiveTime: String = ""

    override init() {
        super.init()

        _niSession = NISession()
        _niSession.delegate = self

        _peripheral = CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: true])

        _central = CBCentralManager(delegate: self, queue: nil)
        _central.delegate = self
    }

    func sendDiscoveryToken() {
        guard let discoveryToken = _niSession.discoveryToken else {
            return
        }

        let data = try! NSKeyedArchiver.archivedData(withRootObject: discoveryToken, requiringSecureCoding: true)

        _transferCharacteristic.value = data
        _peripheral.updateValue(_transferCharacteristic.value!, for: _transferCharacteristic, onSubscribedCentrals: nil)
    }
}

extension HandsfreeUWB: NISessionDelegate {
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        for object in nearbyObjects {
            let discoveredPeer = DiscoveredPeer(token: object.discoveryToken, distance: object.distance ?? 0.0, direction: object.direction)
            print("PeerInfo: \(discoveredPeer)")
            distance = discoveredPeer.distance
            if let index = discoveredPeers.firstIndex(where: { $0.token == object.discoveryToken }) {
                discoveredPeers[index] = discoveredPeer
            } else {
                discoveredPeers.append(discoveredPeer)
            }
        }
    }
}

extension HandsfreeUWB: CBPeripheralManagerDelegate {
    // Peripheralの状態が変わった時に呼ばれる
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral.state == .poweredOn else { return }

        _transferCharacteristic = CBMutableCharacteristic(
            type: CHARACTERISTIC_UUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        let transferService = CBMutableService(
            type: SERVICE_UUID,
            primary: true
        )
        transferService.characteristics = [_transferCharacteristic]

        peripheral.add(transferService)
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [transferService.uuid],
            CBAdvertisementDataLocalNameKey: UIDevice.current.name
        ])
    }
}

extension HandsfreeUWB: CBCentralManagerDelegate {
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {}

    // Centralの状態が変わった時に呼ばれる
    // ここで自身のSERVICE_UUIDのサービスに紐づくPeripheralを探しに行く
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else { return }

        central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
        }
    }

    // Peripheralが見つかった時に呼ばれる
    // 見つけたPeripheralをCentralに接続する
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        peripherals.append(peripheral)
        connectionAttempts = 0
        central.connect(peripheral, options: nil)
    }

    // CentralとPeripheralの接続が完了した時に呼ばれる
    // Peripheralの状態を受け取るために、delegateを設定し、Peripheralが保持しているServiceを検索する
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([SERVICE_UUID])
        connectionAttempts = 0
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionAttempts += 1 // 接続試行回数を増やす

        if connectionAttempts < maxConnectionAttempts {
            central.connect(peripheral, options: nil) // 接続試行回数が最大回数未満なら再接続を試みる
        } else {
            if let index = peripherals.firstIndex(of: peripheral) {
                peripherals.remove(at: index) // 最大接続試行回数に達したPeripheralをリストから削除
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionAttempts += 1 // 接続試行回数を増やす

        if connectionAttempts < maxConnectionAttempts {
            central.connect(peripheral, options: nil) // 接続試行回数が最大回数未満なら再接続を試みる
        } else {
            if let index = peripherals.firstIndex(of: peripheral) {
                peripherals.remove(at: index) // 最大接続試行回数に達したPeripheralをリストから削除
            }
        }

        // 接続が切れたので、指定した間隔後にスキャンを再開
        DispatchQueue.main.asyncAfter(deadline: .now() + scanInterval) {
            if central.isScanning {
                central.stopScan() // もし既にスキャン中なら、一度スキャンを停止
            }
            central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
        }
    }
}

extension HandsfreeUWB: CBPeripheralDelegate {
    // Peripheralが保持しているServiceを見つけた時に呼ばれる
    // 次に、Serviceの中に含まれているCharacteristicを探す
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == SERVICE_UUID }) else { return }
        peripheral.discoverCharacteristics([CHARACTERISTIC_UUID], for: service)
    }

    // Serviceの中に含まれているCharacteristicを見つけた時に呼ばれる
    // Characteristicの通知を許可して購読を始める
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == CHARACTERISTIC_UUID }) else { return }
        peripheral.setNotifyValue(true, for: characteristic)
    }

    // Characteristicの更新がかかった時に呼ばれる
    // ここで相手型のdiscoveryTokenを手にいれる
    // 受け取った瞬間に自分のも送る（現状1:1のみを想定）
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            return
        }

        do {
            guard let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
                return
            }

            let config = NINearbyPeerConfiguration(peerToken: discoveryToken)
            _niSession.run(config)

            receiveTime = Date().description

            sendDiscoveryToken()
        } catch {}
    }
}
