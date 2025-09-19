//
//  BLEUtilities.swift
//  BLEKitDemo
//
//  Created by sf Hsing on 9/19/25.
//

import Foundation
import BLEKit
import CoreBluetooth

/// Utility functions for BLE operations in the demo app
public struct BLEUtilities {
    
    // MARK: - Bluetooth State Utilities
    
    /// Convert CBManagerState to human-readable string
    public static func bluetoothStatusString(for state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "Unknown"
        case .resetting:
            return "Resetting"
        case .unsupported:
            return "Unsupported"
        case .unauthorized:
            return "Unauthorized"
        case .poweredOff:
            return "Powered Off"
        case .poweredOn:
            return "Powered On"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Check if Bluetooth is ready for operations
    public static func isBluetoothReady(_ state: CBManagerState) -> Bool {
        return state == .poweredOn
    }
    
    
    // MARK: - Connection Utilities
    
    /// Check if a device is currently connected
    public static func isDeviceConnected(_ device: BLEPeripheral) -> Bool {
        return BLEManager.shared.connectedPeripherals.contains { $0.identifier == device.identifier }
    }

}
