import Foundation
import CoreBluetooth

/// Service for Bluetooth communication with AccuChek devices
@MainActor
public final class BluetoothService: NSObject, ObservableObject {
    @Published public private(set) var isScanning = false
    @Published public private(set) var discoveredDevices: [DiscoveredDevice] = []
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var lastError: BluetoothError?

    private var centralManager: CBCentralManager?
    private var connectedPeripheral: CBPeripheral?
    private var dataCharacteristic: CBCharacteristic?

    // AccuChek BLE Service UUIDs (typical for glucose meters)
    private let glucoseServiceUUID = CBUUID(string: "1808")  // Glucose Service
    private let glucoseMeasurementUUID = CBUUID(string: "2A18")  // Glucose Measurement
    private let glucoseFeatureUUID = CBUUID(string: "2A51")  // Glucose Feature
    private let recordAccessControlPointUUID = CBUUID(string: "2A52")  // Record Access Control Point

    public override init() {
        super.init()
    }

    /// Start the Bluetooth service
    public func start() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Start scanning for AccuChek devices
    public func startScanning() {
        guard let manager = centralManager, manager.state == .poweredOn else {
            lastError = .bluetoothNotAvailable
            return
        }

        isScanning = true
        discoveredDevices.removeAll()
        manager.scanForPeripherals(
            withServices: [glucoseServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        // Stop scanning after 10 seconds
        Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            await MainActor.run {
                stopScanning()
            }
        }
    }

    /// Stop scanning for devices
    public func stopScanning() {
        centralManager?.stopScan()
        isScanning = false
    }

    /// Connect to a discovered device
    public func connect(to device: DiscoveredDevice) {
        guard let manager = centralManager else { return }
        connectionState = .connecting
        manager.connect(device.peripheral, options: nil)
    }

    /// Disconnect from the current device
    public func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager?.cancelPeripheralConnection(peripheral)
    }

    /// Request all glucose records from the connected device
    public func requestAllRecords() async throws -> [GlucoseSample] {
        guard connectionState == .connected,
              let characteristic = dataCharacteristic else {
            throw BluetoothError.notConnected
        }

        // Write Record Access Control Point command to get all records
        // Op Code: 0x01 (Report all records)
        let command = Data([0x01, 0x01])  // Report all records
        connectedPeripheral?.writeValue(command, for: characteristic, type: .withResponse)

        // In a real implementation, we would wait for notifications
        // For now, return empty array as placeholder
        return []
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothService: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("Bluetooth is powered on")
            case .poweredOff:
                lastError = .bluetoothPoweredOff
            case .unauthorized:
                lastError = .bluetoothUnauthorized
            case .unsupported:
                lastError = .bluetoothUnsupported
            default:
                break
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            let device = DiscoveredDevice(
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown Device",
                rssi: RSSI.intValue
            )

            if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices.append(device)
            }
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            connectedPeripheral = peripheral
            peripheral.delegate = self
            connectionState = .connected
            peripheral.discoverServices([glucoseServiceUUID])
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
            lastError = .connectionFailed(error?.localizedDescription ?? "Unknown error")
        }
    }

    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            connectedPeripheral = nil
            connectionState = .disconnected
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothService: CBPeripheralDelegate {
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(
                [glucoseMeasurementUUID, recordAccessControlPointUUID],
                for: service
            )
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == recordAccessControlPointUUID {
                Task { @MainActor in
                    dataCharacteristic = characteristic
                }
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == glucoseMeasurementUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }

        // Parse glucose measurement data
        // This would need to be implemented based on the Bluetooth Glucose Profile specification
        print("Received data: \(data.map { String(format: "%02X", $0) }.joined())")
    }
}

// MARK: - Supporting Types

public struct DiscoveredDevice: Identifiable {
    public let id = UUID()
    public let peripheral: CBPeripheral
    public let name: String
    public let rssi: Int

    public init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
    }
}

public enum ConnectionState: String, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
}

public enum BluetoothError: Error, LocalizedError {
    case bluetoothNotAvailable
    case bluetoothPoweredOff
    case bluetoothUnauthorized
    case bluetoothUnsupported
    case notConnected
    case connectionFailed(String)
    case dataTransferFailed(String)

    public var errorDescription: String? {
        switch self {
        case .bluetoothNotAvailable:
            return "Bluetooth is not available"
        case .bluetoothPoweredOff:
            return "Bluetooth is powered off"
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized"
        case .bluetoothUnsupported:
            return "Bluetooth is not supported on this device"
        case .notConnected:
            return "Not connected to any device"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .dataTransferFailed(let message):
            return "Data transfer failed: \(message)"
        }
    }
}
