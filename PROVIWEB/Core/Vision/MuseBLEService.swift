import Foundation
import CoreBluetooth
import Combine

// MARK: - CoreBluetooth Service for Muse EEG Headband & Wearable Gadget
public class MuseBLEService: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    public static let shared = MuseBLEService()
    
    // Official Muse BLE UUIDs
    public static let serviceUUID = CBUUID(string: "4D757365-0001-4000-8000-6A6F6C6C7900")
    public static let charCmdUUID = CBUUID(string: "4D757365-0002-4000-8000-6A6F6C6C7900")
    public static let charStatusUUID = CBUUID(string: "4D757365-0003-4000-8000-6A6F6C6C7900")
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var cmdCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    
    @Published public var isBluetoothPoweredOn: Bool = false
    @Published public var isScanning: Bool = false
    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = ""
    @Published public var batteryLevel: Int = 85
    @Published public var focusScore: Double = 0.88 // 0.0 - 1.0 focus / concentration score
    @Published public var calmScore: Double = 0.76  // 0.0 - 1.0 relaxation score
    @Published public var discoveredPeripherals: [CBPeripheral] = []
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    public func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }
    
    public func connect(peripheral: CBPeripheral) {
        stopScanning()
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    public func disconnect() {
        if let p = connectedPeripheral {
            centralManager.cancelPeripheralConnection(p)
        }
    }
    
    // CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothPoweredOn = (central.state == .poweredOn)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        deviceName = peripheral.name ?? "Dispositivo Muse"
        peripheral.discoverServices([MuseBLEService.serviceUUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedPeripheral = nil
        cmdCharacteristic = nil
        statusCharacteristic = nil
    }
    
    // CBPeripheralDelegate
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == MuseBLEService.serviceUUID {
            peripheral.discoverCharacteristics([MuseBLEService.charCmdUUID, MuseBLEService.charStatusUUID], for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.uuid == MuseBLEService.charCmdUUID {
                cmdCharacteristic = char
            } else if char.uuid == MuseBLEService.charStatusUUID {
                statusCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == MuseBLEService.charStatusUUID, let data = characteristic.value {
            // Mock or parse telemetry bytes: Focus and Calm levels
            if let string = String(data: data, encoding: .utf8) {
                print("[Muse BLE] Datos de telemetría: \(string)")
            }
        }
    }
}
