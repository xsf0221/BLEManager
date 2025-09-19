//
//  MockObjects.swift
//  BLEKitTests
//
//  Created by sf Hsing on 9/18/25.
//

import Foundation
import CoreBluetooth
import Combine
@testable import BLEKit

/// Test helper extension for BLEPeripheral
extension BLEPeripheral {
    /// Create a test BLEPeripheral without CBPeripheral dependency
    static func createForTesting(identifier: UUID = UUID(), name: String? = nil, manufacturerData: Data? = nil, rssi: NSNumber = -50) -> BLEPeripheral {
        return BLEPeripheral(testIdentifier: identifier, testName: name, testManufacturerData: manufacturerData, testRssi: rssi)
    }
}

/// Mock CBCentralManager for testing
class MockCBCentralManager: NSObject {
    var mockState: CBManagerState
    var scanningServices: [CBUUID]?
    var scanningOptions: [String: Any]?
    var mockIsScanning: Bool = false
    
    init(state: CBManagerState) {
        self.mockState = state
        super.init()
    }
    
    var state: CBManagerState {
        return mockState
    }
    
    var isScanning: Bool {
        return mockIsScanning
    }
    
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        scanningServices = serviceUUIDs
        scanningOptions = options
        mockIsScanning = true
    }
    
    func stopScan() {
        mockIsScanning = false
    }
    
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        // Simulate connection in tests
    }
    
    func cancelPeripheralConnection(_ peripheral: CBPeripheral) {
        // Simulate disconnection in tests
    }
}

/// Mock BLEManager for testing - uses protocol-based approach since singleton can't be inherited
protocol MockBLEManagerProtocol {
    var discoveredPeripherals: [BLEPeripheral] { get }
    var connectedPeripherals: [BLEPeripheral] { get }
    var bluetoothState: CBManagerState { get }
    var isScanning: Bool { get }

    func configure(with configuration: BLEManagerConfiguration)
    func startScanning(serviceUUIDs: [CBUUID]?, allowDuplicates: Bool) throws
    func stopScanning()
    func connect(to peripheral: BLEPeripheral) throws
    func disconnect(from peripheral: BLEPeripheral) throws
}

/// Mock BLEManager implementation for testing
class MockBLEManager: ObservableObject, MockBLEManagerProtocol {
    @Published private(set) var discoveredPeripherals: [BLEPeripheral] = []
    @Published private(set) var connectedPeripherals: [BLEPeripheral] = []
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isScanning: Bool = false

    // Event publishers matching real BLEManager
    let deviceDiscovered = PassthroughSubject<BLEPeripheral, Never>()
    let deviceConnected = PassthroughSubject<BLEPeripheral, Never>()
    let deviceDisconnected = PassthroughSubject<(peripheral: BLEPeripheral, error: Error?), Never>()
    let deviceConnectionFailed = PassthroughSubject<(peripheral: BLEPeripheral, error: Error?), Never>()

    private let mockCentralManager: MockCBCentralManager
    private var peripheralMap: [UUID: BLEPeripheral] = [:]
    private var isConfigured = false

    init(initialState: CBManagerState) {
        self.mockCentralManager = MockCBCentralManager(state: initialState)
        self.bluetoothState = initialState
    }

    func configure(with configuration: BLEManagerConfiguration = .default) {
        guard !isConfigured else { return }
        isConfigured = true
    }

    func startScanning(serviceUUIDs: [CBUUID]? = nil, allowDuplicates: Bool = false) throws {
        guard bluetoothState == .poweredOn else {
            switch bluetoothState {
            case .unauthorized:
                throw BLEError.unauthorized
            default:
                throw BLEError.bluetoothUnavailable
            }
        }

        guard !isScanning else { return }

        discoveredPeripherals.removeAll()
        peripheralMap.removeAll()

        mockCentralManager.scanForPeripherals(withServices: serviceUUIDs, options: nil)
        isScanning = true
    }

    func stopScanning() {
        guard isScanning else { return }
        mockCentralManager.stopScan()
        isScanning = false
    }

    func connect(to peripheral: BLEPeripheral) throws {
        guard bluetoothState == .poweredOn else {
            throw BLEError.bluetoothUnavailable
        }

        guard !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else {
            throw BLEError.alreadyConnected
        }

        // Simulate connection - in real tests this would be triggered by test methods
    }

    func disconnect(from peripheral: BLEPeripheral) throws {
        guard connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else {
            throw BLEError.notConnected
        }

        // Simulate disconnection - in real tests this would be triggered by test methods
    }

    func peripheral(with identifier: UUID) -> BLEPeripheral? {
        return peripheralMap[identifier]
    }

    // MARK: - Test Simulation Methods

    func simulatePeripheralDiscovery(_ peripheral: BLEPeripheral) {
        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
        peripheralMap[peripheral.identifier] = peripheral
        deviceDiscovered.send(peripheral)
    }

    func simulateConnection(to peripheral: BLEPeripheral) {
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }
        peripheralMap[peripheral.identifier] = peripheral
        deviceConnected.send(peripheral)
    }

    func simulateDisconnection(from peripheral: BLEPeripheral, error: Error?) {
        connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
        deviceDisconnected.send((peripheral: peripheral, error: error))
    }

    func simulateConnectionFailure(to peripheral: BLEPeripheral, error: Error?) {
        deviceConnectionFailed.send((peripheral: peripheral, error: error))
    }

    func updateState(_ state: CBManagerState) {
        bluetoothState = state
        if state != .poweredOn && isScanning {
            isScanning = false
        }
    }
}

/// Test helper for capturing Combine events
class CombineTestHelper {
    var discoveredPeripherals: [BLEPeripheral] = []
    var connectedPeripherals: [BLEPeripheral] = []
    var disconnectedPeripherals: [BLEPeripheral] = []
    var failedConnections: [(BLEPeripheral, Error?)] = []
    var stateUpdates: [CBManagerState] = []

    private var cancellables = Set<AnyCancellable>()

    func subscribe(to manager: MockBLEManager) {
        manager.deviceDiscovered
            .sink { [weak self] peripheral in
                self?.discoveredPeripherals.append(peripheral)
            }
            .store(in: &cancellables)

        manager.deviceConnected
            .sink { [weak self] peripheral in
                self?.connectedPeripherals.append(peripheral)
            }
            .store(in: &cancellables)

        manager.deviceDisconnected
            .sink { [weak self] result in
                self?.disconnectedPeripherals.append(result.peripheral)
            }
            .store(in: &cancellables)

        manager.deviceConnectionFailed
            .sink { [weak self] result in
                self?.failedConnections.append((result.peripheral, result.error))
            }
            .store(in: &cancellables)

        manager.$bluetoothState
            .sink { [weak self] state in
                self?.stateUpdates.append(state)
            }
            .store(in: &cancellables)
    }
}