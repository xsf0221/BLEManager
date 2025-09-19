//
//  BLEManager.swift
//  BLEKit
//
//  Created by sf Hsing on 9/18/25.
//

import Foundation
import CoreBluetooth
import Combine

/// Configuration for BLEManager
public struct BLEManagerConfiguration {
    /// The dispatch queue for CBCentralManager operations
    public let queue: DispatchQueue?
    /// Connection timeout interval in seconds
    public let connectionTimeoutInterval: TimeInterval
    /// Initial log level
    public let logLevel: BLELogLevel

    /// Default configuration
    public static let `default` = BLEManagerConfiguration(
        queue: nil,
        connectionTimeoutInterval: 10.0,
        logLevel: .debug
    )

    /// Create a custom configuration
    /// - Parameters:
    ///   - queue: Optional dispatch queue for CBCentralManager operations (nil for main queue)
    ///   - connectionTimeoutInterval: Timeout for connection attempts in seconds
    ///   - logLevel: Initial logging level
    public init(queue: DispatchQueue? = nil,
                connectionTimeoutInterval: TimeInterval = 10.0,
                logLevel: BLELogLevel = .debug) {
        self.queue = queue
        self.connectionTimeoutInterval = connectionTimeoutInterval
        self.logLevel = logLevel
    }
}

/// Main interface for managing Bluetooth Low Energy operations.
///
/// `BLEManager` provides a high-level, SwiftUI-compatible interface for BLE functionality
/// including device discovery, connection management, and real-time state monitoring.
/// The manager uses Combine publishers for reactive programming and `@Published` properties
/// for seamless SwiftUI integration.
///
/// ## Key Features
/// - Singleton design pattern for centralized BLE management
/// - Reactive state updates through Combine publishers
/// - SwiftUI-compatible with `@Published` properties
/// - Configurable logging and connection timeouts
/// - Automatic resource cleanup and memory management
///
/// ## Basic Usage
/// ```swift
/// // Configure before first use (optional - defaults will be used otherwise)
/// BLEManager.shared.configure(with: .default)
///
/// // Start scanning for devices
/// try BLEManager.shared.startScanning()
///
/// // Connect to a discovered device
/// if let device = BLEManager.shared.discoveredPeripherals.first {
///     try BLEManager.shared.connect(to: device)
/// }
/// ```
///
/// ## SwiftUI Integration
/// ```swift
/// struct ContentView: View {
///     @StateObject private var bleManager = BLEManager.shared
///
///     var body: some View {
///         List(bleManager.discoveredPeripherals, id: \.identifier) { device in
///             Text(device.name ?? "Unknown Device")
///         }
///     }
/// }
/// ```
@available(iOS 13.0, macOS 10.15, *)
public class BLEManager: NSObject, ObservableObject {
    /// Shared singleton instance for centralized BLE management.
    ///
    /// Use this shared instance throughout your app to ensure consistent state
    /// and avoid conflicts between multiple BLE manager instances.
    public static let shared = BLEManager()
    
    
    // MARK: - Published Properties
    /// Array of peripherals discovered during the current or most recent scan.
    ///
    /// This property automatically updates when new devices are discovered during scanning.
    /// The array is cleared each time a new scan begins. In SwiftUI, changes to this
    /// property will automatically trigger view updates.
    ///
    /// - Note: Peripherals remain in this array even after scanning stops, until a new scan begins.
    @Published public private(set) var discoveredPeripherals: [BLEPeripheral] = []

    /// Array of peripherals currently connected to this central manager.
    ///
    /// This property reflects the real-time connection state. Peripherals are added when
    /// connection succeeds and removed when disconnection occurs (either initiated by
    /// the app or by the peripheral).
    @Published public private(set) var connectedPeripherals: [BLEPeripheral] = []

    /// The current state of the underlying Core Bluetooth central manager.
    ///
    /// This property reflects the system-level Bluetooth state and determines what
    /// operations are available. Key states include:
    /// - `.poweredOn`: Bluetooth is available and ready for use
    /// - `.poweredOff`: Bluetooth is turned off
    /// - `.unauthorized`: App lacks Bluetooth permissions
    /// - `.unknown`: Initial state before determination
    @Published public private(set) var bluetoothState: CBManagerState = .unknown

    /// Indicates whether the manager is currently scanning for peripherals.
    ///
    /// This property automatically updates when scanning starts or stops, including
    /// when scanning is automatically stopped due to Bluetooth state changes.
    @Published public private(set) var isScanning: Bool = false
    
    // MARK: - Event Publishers
    /// Publisher that emits newly discovered peripherals during scanning.
    ///
    /// Subscribe to this publisher to receive real-time notifications when devices
    /// are discovered. This is useful for implementing custom filtering or immediate
    /// responses to specific device types.
    ///
    /// ## Usage Example
    /// ```swift
    /// BLEManager.shared.deviceDiscovered
    ///     .filter { $0.name?.contains("MyDevice") == true }
    ///     .sink { device in
    ///         print("Found target device: \(device.name!)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public let deviceDiscovered = PassthroughSubject<BLEPeripheral, Never>()

    /// Publisher that emits when a peripheral successfully connects.
    ///
    /// This publisher fires when the connection process completes successfully.
    /// Use this to trigger immediate actions upon connection, such as service discovery.
    ///
    /// ## Usage Example
    /// ```swift
    /// BLEManager.shared.deviceConnected
    ///     .sink { peripheral in
    ///         print("Connected to \(peripheral.name ?? "Unknown")")
    ///         // Start service discovery or other post-connection tasks
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public let deviceConnected = PassthroughSubject<BLEPeripheral, Never>()

    /// Publisher that emits when a peripheral disconnects.
    ///
    /// This publisher provides both the disconnected peripheral and an optional error
    /// that may have caused the disconnection. A `nil` error indicates a clean,
    /// intentional disconnection.
    ///
    /// ## Usage Example
    /// ```swift
    /// BLEManager.shared.deviceDisconnected
    ///     .sink { (peripheral, error) in
    ///         if let error = error {
    ///             print("Disconnected from \(peripheral.name ?? "Unknown") due to error: \(error)")
    ///         } else {
    ///             print("Cleanly disconnected from \(peripheral.name ?? "Unknown")")
    ///         }
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public let deviceDisconnected = PassthroughSubject<(peripheral: BLEPeripheral, error: Error?), Never>()

    /// Publisher that emits when a connection attempt fails.
    ///
    /// This publisher fires when an attempted connection fails, providing both the
    /// target peripheral and the error that caused the failure. Use this to implement
    /// retry logic or user error messaging.
    ///
    /// ## Usage Example
    /// ```swift
    /// BLEManager.shared.deviceConnectionFailed
    ///     .sink { (peripheral, error) in
    ///         print("Failed to connect to \(peripheral.name ?? "Unknown"): \(error?.localizedDescription ?? "Unknown error")")
    ///         // Implement retry logic or show user message
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public let deviceConnectionFailed = PassthroughSubject<(peripheral: BLEPeripheral, error: Error?), Never>()
    
    /// The current Bluetooth state (deprecated - use `bluetoothState` instead).
    ///
    /// This property provides backward compatibility with earlier versions of BLEKit.
    /// For new code, use the `bluetoothState` published property instead, which provides
    /// better SwiftUI integration and reactive updates.
    ///
    /// - Warning: This property is deprecated and will be removed in a future version.
    ///   Use `bluetoothState` for new development.
    ///
    /// ## Migration Guide
    /// ```swift
    /// // Old way (deprecated)
    /// if BLEManager.shared.state == .poweredOn {
    ///     // ...
    /// }
    ///
    /// // New way (recommended)
    /// if BLEManager.shared.bluetoothState == .poweredOn {
    ///     // ...
    /// }
    /// ```
    @available(*, deprecated, message: "Use bluetoothState instead for better SwiftUI integration")
    public var state: CBManagerState {
        ensureConfigured()
        return bluetoothState
    }
    
    private var centralManager: CBCentralManager!
    private var peripheralMap: [UUID: BLEPeripheral] = [:]
    private var connectionTimeouts: [UUID: Timer] = [:]
    private var connectionTimeoutInterval: TimeInterval = 10.0
    private var isConfigured = false

    /// Private initializer for singleton
    private override init() {
        super.init()
        // CBCentralManager will be initialized when configure() is called
        // If not configured, use default configuration on first access
    }

    /// Configure the BLE manager with custom settings
    /// - Parameter configuration: The configuration to use
    /// - Note: This method should be called before first accessing any BLE functionality
    public func configure(with configuration: BLEManagerConfiguration = .default) {
        guard !isConfigured else {
            BLELogger.shared.warning("BLEManager is already configured. Ignoring reconfiguration attempt.")
            return
        }

        // Store configuration values
        self.connectionTimeoutInterval = configuration.connectionTimeoutInterval

        // Configure logger
        BLELogger.shared.minimumLogLevel = configuration.logLevel

        // Initialize CBCentralManager with the configured queue
        centralManager = CBCentralManager(delegate: self, queue: configuration.queue)
        bluetoothState = centralManager.state

        isConfigured = true
        BLELogger.shared.debug("BLEManager configured with custom settings")
    }

    /// Ensures BLEManager is configured before use
    private func ensureConfigured() {
        if !isConfigured {
            configure(with: .default)
        }
    }
    
    /// Configure the logger level for BLE operations
    /// - Parameter level: The minimum log level to display
    public func configureLogger(level: BLELogLevel) {
        BLELogger.shared.minimumLogLevel = level
        BLELogger.shared.info("Logger level configured to: \(level)")
    }
    
    /// Start scanning for BLE peripherals
    /// - Parameters:
    ///   - serviceUUIDs: Optional array of service UUIDs to filter by
    ///   - allowDuplicates: Whether to report duplicate discoveries
    /// - Throws: BLEError if scanning cannot be started
    public func startScanning(serviceUUIDs: [CBUUID]? = nil, allowDuplicates: Bool = false) throws {
        ensureConfigured()
        guard centralManager.state == .poweredOn else {
            switch centralManager.state {
            case .unauthorized:
                throw BLEError.unauthorized
            default:
                throw BLEError.bluetoothUnavailable
            }
        }
        
        guard !isScanning else {
            BLELogger.shared.warning("Scanning already in progress, ignoring start scanning request")
            return
        }
        
        discoveredPeripherals.removeAll()
        peripheralMap.removeAll()
        
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates]
        centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
        isScanning = true
        
        let serviceInfo = serviceUUIDs?.map { $0.uuidString }.joined(separator: ", ") ?? "all services"
        BLELogger.shared.info("Started scanning for BLE peripherals (services: \(serviceInfo), allowDuplicates: \(allowDuplicates))")
    }
    
    /// Stop scanning for BLE peripherals
    public func stopScanning() {
        ensureConfigured()
        guard isScanning else {
            BLELogger.shared.debug("Stop scanning requested but scanning is not active")
            return
        }
        centralManager.stopScan()
        isScanning = false
        BLELogger.shared.info("Stopped scanning for peripherals")
    }
    
    /// Connect to a discovered peripheral
    /// - Parameter peripheral: The BLE peripheral to connect to
    /// - Throws: BLEError if connection cannot be initiated
    public func connect(to peripheral: BLEPeripheral) throws {
        ensureConfigured()
        guard centralManager.state == .poweredOn else {
            throw BLEError.bluetoothUnavailable
        }
        
        guard !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else {
            throw BLEError.alreadyConnected
        }
        
        guard let cbPeripheral = peripheral.cbPeripheral else {
            throw BLEError.peripheralNotFound
        }
        centralManager.connect(cbPeripheral, options: nil)
        BLELogger.shared.info("connecting to peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
        
        let timeout = Timer.scheduledTimer(withTimeInterval: connectionTimeoutInterval, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout(for: peripheral)
        }
        connectionTimeouts[peripheral.identifier] = timeout
    }
    
    /// Disconnect from a connected peripheral
    /// - Parameter peripheral: The BLE peripheral to disconnect from
    /// - Throws: BLEError if not connected to the peripheral
    public func disconnect(from peripheral: BLEPeripheral) throws {
        ensureConfigured()
        // check whether the connecting peripheral is the arg0
        guard connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else {
            throw BLEError.notConnected
        }
        
        guard let cbPeripheral = peripheral.cbPeripheral else {
            throw BLEError.peripheralNotFound
        }
        centralManager.cancelPeripheralConnection(cbPeripheral)
        connectionTimeouts[peripheral.identifier]?.invalidate()
        connectionTimeouts.removeValue(forKey: peripheral.identifier)
        BLELogger.shared.info("Initiated disconnection from peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
    }
    
    /// Get a discovered peripheral by the identifier
    /// - Parameter identifier: The UUID identifier of the peripheral
    /// - Returns: The BLE peripheral if found, or nil
    public func peripheral(with identifier: UUID) -> BLEPeripheral? {
        return peripheralMap[identifier]
    }
    
    
    // MARK: - Private Methods
    private func addDiscoveredPeripheral(_ peripheral: BLEPeripheral) {
        if let existingIndex = discoveredPeripherals.firstIndex(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals[existingIndex] = peripheral
        } else {
            discoveredPeripherals.append(peripheral)
        }
        peripheralMap[peripheral.identifier] = peripheral
    }
    
    private func handleConnectionTimeout(for peripheral: BLEPeripheral) {
        connectionTimeouts.removeValue(forKey: peripheral.identifier)
        guard let cbPeripheral = peripheral.cbPeripheral else {
            BLELogger.shared.error("Connection timeout failed - no CBPeripheral for: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
            deviceConnectionFailed.send((peripheral: peripheral, error: BLEError.peripheralNotFound))
            return
        }
        centralManager.cancelPeripheralConnection(cbPeripheral)
        BLELogger.shared.warning("Connection timeout for peripheral: \(peripheral.name ?? "Unknown") (\(peripheral.identifier))")
        deviceConnectionFailed.send((peripheral: peripheral, error: BLEError.connectionTimeout))
    }
    
    private func addConnectedPeripheral(_ peripheral: BLEPeripheral) {
        if !connectedPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            connectedPeripherals.append(peripheral)
        }
    }
    
    private func removeConnectedPeripheral(_ peripheral: BLEPeripheral) {
        connectedPeripherals.removeAll { $0.identifier == peripheral.identifier }
    }
    
    // MARK: - Deinitialization
    deinit {
        // Stop scanning if active
        if isScanning {
            stopScanning()
        }
        
        // Disconnect all peripherals
        for peripheral in connectedPeripherals {
            if let cbPeripheral = peripheral.cbPeripheral {
                centralManager.cancelPeripheralConnection(cbPeripheral)
            }
        }
        
        // Invalidate all connection timeout timers
        for (_, timeout) in connectionTimeouts {
            timeout.invalidate()
        }
        connectionTimeouts.removeAll()
        
        // Clear references
        peripheralMap.removeAll()
        discoveredPeripherals.removeAll()
        connectedPeripherals.removeAll()
        
        BLELogger.shared.debug("BLEManager deinitialized and resources released")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let stateDescription: String
        switch central.state {
        case .unknown:
            stateDescription = "Unknown"
        case .resetting:
            stateDescription = "Resetting"
        case .unsupported:
            stateDescription = "Unsupported"
        case .unauthorized:
            stateDescription = "Unauthorized"
        case .poweredOff:
            stateDescription = "Powered Off"
        case .poweredOn:
            stateDescription = "Powered On"
        @unknown default:
            stateDescription = "Unknown State"
        }
        
        // Update published state
        bluetoothState = central.state
        
        BLELogger.shared.info("Bluetooth state changed to: \(stateDescription)")
        
        if central.state != .poweredOn && isScanning {
            isScanning = false
            BLELogger.shared.warning("Scanning stopped due to Bluetooth state change")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let blePeripheral = BLEPeripheral(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        addDiscoveredPeripheral(blePeripheral)
        
        let manufacturerInfo = blePeripheral.manufacturerData != nil ? " (has manufacturer data)" : ""
        BLELogger.shared.debug("Discovered peripheral: \(blePeripheral.name ?? "Unknown") (\(blePeripheral.identifier)), RSSI: \(RSSI) dBm\(manufacturerInfo)")
        
        // Publish to Combine subscribers
        deviceDiscovered.send(blePeripheral)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionTimeouts[peripheral.identifier]?.invalidate()
        connectionTimeouts.removeValue(forKey: peripheral.identifier)
        
        if let blePeripheral = peripheralMap[peripheral.identifier] {
            addConnectedPeripheral(blePeripheral)
            BLELogger.shared.info("Successfully connected to peripheral: \(blePeripheral.name ?? "Unknown") (\(blePeripheral.identifier))")
            
            // Publish to Combine subscribers
            deviceConnected.send(blePeripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeouts[peripheral.identifier]?.invalidate()
        connectionTimeouts.removeValue(forKey: peripheral.identifier)
        
        if let blePeripheral = peripheralMap[peripheral.identifier] {
            let errorDescription = error?.localizedDescription ?? "Unknown error"
            BLELogger.shared.error("Failed to connect to peripheral: \(blePeripheral.name ?? "Unknown") (\(blePeripheral.identifier)) - \(errorDescription)")
            
            // Publish to Combine subscribers
            deviceConnectionFailed.send((peripheral: blePeripheral, error: error))
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let blePeripheral = peripheralMap[peripheral.identifier] {
            removeConnectedPeripheral(blePeripheral)
            
            if let error = error {
                BLELogger.shared.warning("Disconnected from peripheral: \(blePeripheral.name ?? "Unknown") (\(blePeripheral.identifier)) with error: \(error.localizedDescription)")
            } else {
                BLELogger.shared.info("Successfully disconnected from peripheral: \(blePeripheral.name ?? "Unknown") (\(blePeripheral.identifier))")
            }
            
            // Publish to Combine subscribers
            deviceDisconnected.send((peripheral: blePeripheral, error: error))
        }
    }
}
