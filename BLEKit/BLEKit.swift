//
//  BLEKit.swift
//  BLEKit
//
//  Created by sf Hsing on 9/18/25.
//

import Foundation
import CoreBluetooth

// MARK: - BLEKit SDK Main Components
//
// This file defines the core types and protocols for the BLEKit SDK:
// - BLEPeripheral: Represents a discovered BLE device
// - BLEManagerDelegate: Protocol for receiving BLE events
// - BLEError: Error types for BLE operations
// - BLELogger: Centralized logging system (defined in BLELogger.swift)


/// Represents a Bluetooth Low Energy peripheral device discovered during scanning.
///
/// `BLEPeripheral` encapsulates information about a BLE device including its unique identifier,
/// advertised name, manufacturer-specific data, and signal strength. This structure provides
/// a convenient wrapper around Core Bluetooth's `CBPeripheral` with additional metadata.
///
/// ## Usage Example
/// ```swift
/// // Access discovered peripherals
/// let peripherals = BLEManager.shared.discoveredPeripherals
/// for peripheral in peripherals {
///     print("Device: \(peripheral.name ?? "Unknown") - RSSI: \(peripheral.rssi)")
/// }
/// ```
public struct BLEPeripheral {
    /// The unique identifier of the peripheral.
    ///
    /// This identifier is persistent across app launches and can be used to reconnect
    /// to previously known devices.
    public let identifier: UUID

    /// The advertised name of the peripheral.
    ///
    /// This value can be `nil` if the device doesn't advertise a name or if the name
    /// is not available in the advertisement data.
    public let name: String?

    /// The manufacturer-specific data advertised by the peripheral.
    ///
    /// This optional data contains manufacturer-specific information that can be used
    /// to identify device types or access vendor-specific features.
    public let manufacturerData: Data?

    /// The received signal strength indicator in dBm.
    ///
    /// RSSI values typically range from -100 dBm (weak signal) to 0 dBm (strong signal).
    /// This value can be used to estimate the distance to the device and filter by proximity.
    public let rssi: NSNumber
    
    /// The underlying Core Bluetooth peripheral object (optional for testing)
    internal let cbPeripheral: CBPeripheral?
    
    internal init(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        self.identifier = peripheral.identifier
        self.name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        self.manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        self.rssi = rssi
        self.cbPeripheral = peripheral
    }
    
    #if DEBUG
    /// Test-only initializer for creating BLEPeripheral without CBPeripheral dependency
    internal init(testIdentifier: UUID, testName: String?, testManufacturerData: Data?, testRssi: NSNumber) {
        self.identifier = testIdentifier
        self.name = testName
        self.manufacturerData = testManufacturerData
        self.rssi = testRssi
        self.cbPeripheral = nil // No CBPeripheral for tests
    }
    #endif
}


/// Errors that can occur during BLE operations.
///
/// `BLEError` provides a comprehensive set of error cases that can occur when working with
/// Bluetooth Low Energy devices. Each error includes a localized description to help with
/// debugging and user messaging.
///
/// ## Common Error Scenarios
/// - **bluetoothUnavailable**: Bluetooth is turned off or not available
/// - **unauthorized**: App doesn't have Bluetooth permissions
/// - **connectionTimeout**: Device connection took too long
/// - **peripheralNotFound**: Device is no longer available
///
/// ## Usage Example
/// ```swift
/// do {
///     try BLEManager.shared.startScanning()
/// } catch BLEError.bluetoothUnavailable {
///     // Show user message to enable Bluetooth
/// } catch BLEError.unauthorized {
///     // Guide user to grant Bluetooth permissions
/// } catch {
///     // Handle other errors
/// }
/// ```
public enum BLEError: LocalizedError {
    /// Bluetooth is turned off or not available on this device.
    case bluetoothUnavailable

    /// The app is not authorized to use Bluetooth.
    case unauthorized

    /// The specified peripheral was not found or is no longer available.
    case peripheralNotFound

    /// Already connected to this peripheral.
    case alreadyConnected

    /// Not currently connected to the peripheral.
    case notConnected

    /// Connection attempt timed out.
    case connectionTimeout

    /// Failed to start scanning for peripherals.
    case scanningFailed
    
    public var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is turned off"
        case .unauthorized:
            return "Bluetooth access is not authorized"
        case .peripheralNotFound:
            return "The specified peripheral was not found"
        case .alreadyConnected:
            return "Already connected to this peripheral"
        case .notConnected:
            return "Not connected to the peripheral"
        case .connectionTimeout:
            return "Connection attempt timed out"
        case .scanningFailed:
            return "Failed to start scanning for peripherals"
        }
    }
}

