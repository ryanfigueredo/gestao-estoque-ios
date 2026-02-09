import Foundation
import Combine
import CoreBluetooth

final class RfidBluetoothManager: NSObject, ObservableObject {
    static let shared = RfidBluetoothManager()

    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting(String)
        case connected(String)
        case error(String)
    }

    @Published var state: ConnectionState = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var lastTagRead: String?
    @Published var onTagRead: ((String) -> Void)?

    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let name: String?
        let peripheral: CBPeripheral
    }

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var tagCharacteristic: CBCharacteristic?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private let savedPeripheralKey = "rfid_saved_peripheral_id"

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            state = .error("Ligue o Bluetooth")
            return
        }
        discoveredDevices.removeAll()
        state = .scanning
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state { state = .disconnected }
    }

    func connect(to device: DiscoveredDevice) {
        stopScanning()
        state = .connecting(device.name ?? device.peripheral.identifier.uuidString)
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
        connectedPeripheral = nil
        tagCharacteristic = nil
        state = .disconnected
        UserDefaults.standard.removeObject(forKey: savedPeripheralKey)
    }

    func tryReconnect() {
        guard let uuidStr = UserDefaults.standard.string(forKey: savedPeripheralKey),
              let uuid = UUID(uuidString: uuidStr) else { return }
        let known = centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let p = known.first {
            reconnectAttempts += 1
            state = .connecting(p.name ?? uuid.uuidString)
            centralManager.connect(p, options: nil)
        }
    }

    private func savePeripheral(_ uuid: UUID) {
        UserDefaults.standard.set(uuid.uuidString, forKey: savedPeripheralKey)
    }

    private func discoverServicesAndCharacteristics(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    private func subscribeToTagCharacteristic(_ characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        tagCharacteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
    }
}

// MARK: - CBCentralManagerDelegate
extension RfidBluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            tryReconnect()
        case .poweredOff:
            state = .error("Bluetooth desligado")
        case .unauthorized, .unsupported:
            state = .error("Bluetooth não autorizado")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Dispositivo"
        if !discoveredDevices.contains(where: { $0.id == peripheral.identifier }) {
            discoveredDevices.append(DiscoveredDevice(id: peripheral.identifier, name: name, peripheral: peripheral))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        reconnectAttempts = 0
        state = .connected(peripheral.name ?? peripheral.identifier.uuidString)
        savePeripheral(peripheral.identifier)
        discoverServicesAndCharacteristics(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        state = .error(error?.localizedDescription ?? "Falha ao conectar")
        if reconnectAttempts < maxReconnectAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.tryReconnect()
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        tagCharacteristic = nil
        if error != nil {
            state = .disconnected
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.tryReconnect()
                }
            }
        } else {
            state = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate
extension RfidBluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                subscribeToTagCharacteristic(char, peripheral: peripheral)
                return
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
            let tag = str.components(separatedBy: .newlines).first ?? str
            lastTagRead = tag
            onTagRead?(tag)
        }
    }
}
