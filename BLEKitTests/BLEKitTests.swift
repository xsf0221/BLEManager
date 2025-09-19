//
//  BLEKitTests.swift
//  BLEKitTests
//
//  Created by sf Hsing on 9/18/25.
//

import Testing
import CoreBluetooth
import Combine
@testable import BLEKit

struct BLEKitTests {
    
    @Test func testBLEPeripheralInitialization() async throws {
        let identifier = UUID()
        let manufacturerData = Data([0x01, 0x02, 0x03])
        let rssi = NSNumber(value: -45)
        
        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: identifier,
            name: "Test Device",
            manufacturerData: manufacturerData,
            rssi: rssi
        )
        
        #expect(blePeripheral.identifier == identifier)
        #expect(blePeripheral.name == "Test Device")
        #expect(blePeripheral.manufacturerData == manufacturerData)
        #expect(blePeripheral.rssi == rssi)
    }
    
    @Test func testBLEPeripheralWithoutAdvertisedName() async throws {
        let identifier = UUID()
        let rssi = NSNumber(value: -60)
        
        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: identifier,
            name: "Device Name",
            manufacturerData: nil,
            rssi: rssi
        )
        
        #expect(blePeripheral.name == "Device Name")
        #expect(blePeripheral.manufacturerData == nil)
    }
    
    @Test func testBLEManagerSingletonAccess() async throws {
        // Test that we can access the singleton and it has expected initial state
        let manager = BLEManager.shared

        #expect(manager.discoveredPeripherals.isEmpty)
        #expect(manager.connectedPeripherals.isEmpty)
        #expect(manager.isScanning == false)
        #expect(manager.bluetoothState == .unknown)
    }
    
    @Test func testScanningWhenBluetoothUnavailable() async throws {
        let manager = MockBLEManager(initialState: .poweredOff)
        
        do {
            try manager.startScanning()
            #expect(Bool(false), "Expected BLEError to be thrown")
        } catch let error as BLEError {
            #expect(error == .bluetoothUnavailable)
        }
    }
    
    @Test func testScanningWhenUnauthorized() async throws {
        let manager = MockBLEManager(initialState: .unauthorized)
        
        do {
            try manager.startScanning()
            #expect(Bool(false), "Expected BLEError to be thrown")
        } catch let error as BLEError {
            #expect(error == .unauthorized)
        }
    }
    
    @Test func testSuccessfulScanning() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        
        #expect(!manager.isScanning)
        try manager.startScanning()
        #expect(manager.isScanning)
        
        manager.stopScanning()
        #expect(!manager.isScanning)
    }
    
    @Test func testConnectingToAlreadyConnectedPeripheral() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test",
            rssi: NSNumber(value: -50)
        )
        
        manager.simulateConnection(to: blePeripheral)
        
        do {
            try manager.connect(to: blePeripheral)
            #expect(Bool(false), "Expected BLEError to be thrown")
        } catch let error as BLEError {
            #expect(error == .alreadyConnected)
        }
    }
    
    @Test func testDisconnectingFromUnconnectedPeripheral() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test",
            rssi: NSNumber(value: -50)
        )
        
        do {
            try manager.disconnect(from: blePeripheral)
            #expect(Bool(false), "Expected BLEError to be thrown")
        } catch let error as BLEError {
            #expect(error == .notConnected)
        }
    }
    
    @Test func testPeripheralDiscoveryEvents() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let testHelper = CombineTestHelper()
        testHelper.subscribe(to: manager)

        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test Device",
            rssi: NSNumber(value: -40)
        )

        manager.simulatePeripheralDiscovery(blePeripheral)

        // Give Combine a moment to process the event
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        #expect(testHelper.discoveredPeripherals.count == 1)
        #expect(testHelper.discoveredPeripherals.first?.identifier == blePeripheral.identifier)
    }
    
    @Test func testConnectionEvents() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let testHelper = CombineTestHelper()
        testHelper.subscribe(to: manager)

        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test Device",
            rssi: NSNumber(value: -40)
        )

        manager.simulateConnection(to: blePeripheral)

        // Give Combine a moment to process the event
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        #expect(testHelper.connectedPeripherals.count == 1)
        #expect(testHelper.connectedPeripherals.first?.identifier == blePeripheral.identifier)
    }
    
    @Test func testDisconnectionEvents() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let testHelper = CombineTestHelper()
        testHelper.subscribe(to: manager)

        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test Device",
            rssi: NSNumber(value: -40)
        )

        manager.simulateConnection(to: blePeripheral)
        manager.simulateDisconnection(from: blePeripheral, error: nil)

        // Give Combine a moment to process the event
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        #expect(testHelper.disconnectedPeripherals.count == 1)
        #expect(testHelper.disconnectedPeripherals.first?.identifier == blePeripheral.identifier)
    }

    // MARK: - Configuration Tests

    @Test func testDefaultConfiguration() async throws {
        let config = BLEManagerConfiguration.default

        #expect(config.queue == nil)
        #expect(config.connectionTimeoutInterval == 10.0)
        #expect(config.logLevel == .debug)
    }

    @Test func testCustomConfiguration() async throws {
        let customQueue = DispatchQueue(label: "test.ble.queue")
        let config = BLEManagerConfiguration(
            queue: customQueue,
            connectionTimeoutInterval: 15.0,
            logLevel: .info
        )

        #expect(config.queue === customQueue)
        #expect(config.connectionTimeoutInterval == 15.0)
        #expect(config.logLevel == .info)
    }

    @Test func testBLEManagerConfiguration() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)

        // Test configuration
        let config = BLEManagerConfiguration(
            queue: nil,
            connectionTimeoutInterval: 20.0,
            logLevel: .error
        )

        manager.configure(with: config)

        // Verify manager is configured (no exception should be thrown)
        #expect(manager.discoveredPeripherals.isEmpty)
    }

    @Test func testBLEManagerDoubleConfiguration() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)

        let config1 = BLEManagerConfiguration(logLevel: .debug)
        let config2 = BLEManagerConfiguration(logLevel: .error)

        manager.configure(with: config1)
        manager.configure(with: config2) // This should be ignored

        // Manager should still work normally
        #expect(manager.bluetoothState == .poweredOn)
    }

    @Test func testConnectionFailureEvents() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)
        let testHelper = CombineTestHelper()
        testHelper.subscribe(to: manager)

        let blePeripheral = BLEPeripheral.createForTesting(
            identifier: UUID(),
            name: "Test Device",
            rssi: NSNumber(value: -40)
        )

        let testError = BLEError.connectionTimeout
        manager.simulateConnectionFailure(to: blePeripheral, error: testError)

        // Give Combine a moment to process the event
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        #expect(testHelper.failedConnections.count == 1)
        #expect(testHelper.failedConnections.first?.0.identifier == blePeripheral.identifier)
    }

    @Test func testStateUpdateEvents() async throws {
        let manager = MockBLEManager(initialState: .unknown)
        let testHelper = CombineTestHelper()
        testHelper.subscribe(to: manager)

        manager.updateState(.poweredOn)

        // Give Combine a moment to process the event
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        #expect(manager.bluetoothState == .poweredOn)
        #expect(testHelper.stateUpdates.contains(.poweredOn))
    }

    @Test func testScanningStopsWhenBluetoothOff() async throws {
        let manager = MockBLEManager(initialState: .poweredOn)

        try manager.startScanning()
        #expect(manager.isScanning == true)

        manager.updateState(.poweredOff)
        #expect(manager.isScanning == false)
    }
}
