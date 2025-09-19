//
//  BLELogger.swift
//  BLEKit
//
//  Created by sf Hsing on 9/18/25.
//

import Foundation
import os.log


public enum BLELogLevel: Int, CaseIterable, CustomStringConvertible {
    /// Debug level - shows all internal operations and detailed information.
    case debug = 0

    /// Info level - shows general information about BLE operations.
    case info = 1

    /// Warning level - shows important issues that don't prevent operation.
    case warning = 2

    /// Error level - shows only critical issues that may cause failures.
    case error = 3
    
    public var description: String {
        switch self {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        }
    }
}

public final class BLELogger {

    // MARK: - Shared Instance

    /// Shared singleton instance for centralized logging.
    public static let shared = BLELogger()
    
    // MARK: - Configuration Properties

    /// Controls whether logging is enabled globally.
    public var isEnabled: Bool = true {
        didSet {
            queue.async { [weak self] in
                self?._isEnabled = self?.isEnabled ?? true
            }
        }
    }

    /// The minimum log level that will be output.
    public var minimumLogLevel: BLELogLevel = .debug {
        didSet {
            queue.async { [weak self] in
                self?._minimumLogLevel = self?.minimumLogLevel ?? .debug
            }
        }
    }

    /// Controls whether timestamps are included in log messages.
    public var includeTimestamp: Bool = true {
        didSet {
            queue.async { [weak self] in
                self?._includeTimestamp = self?.includeTimestamp ?? true
            }
        }
    }

    /// The prefix string added to all log messages.
    public var prefix: String = "[BLEKit]" {
        didSet {
            queue.async { [weak self] in
                self?._prefix = self?.prefix ?? "[BLEKit]"
            }
        }
    }

    /// Controls whether to use the system's unified logging in addition to console output.
    public var useSystemLogging: Bool = false {
        didSet {
            queue.async { [weak self] in
                self?._useSystemLogging = self?.useSystemLogging ?? false
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let queue = DispatchQueue(label: "com.blekit.logger", qos: .utility)
    private let osLog = OSLog(subsystem: "com.blekit.framework", category: "BLEKit")
    
    private var _isEnabled: Bool = true
    private var _minimumLogLevel: BLELogLevel = .debug
    private var _includeTimestamp: Bool = true
    private var _prefix: String = "[BLEKit]"
    private var _useSystemLogging: Bool = false
    
    private lazy var timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Logging Methods

    /// Logs a debug-level message.
    public func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    /// Logs an info-level message.
    public func info(_ message: String) {
        log(level: .info, message: message)
    }

    /// Logs a warning-level message.
    public func warning(_ message: String) {
        log(level: .warning, message: message)
    }

    /// Logs an error-level message.
    public func error(_ message: String) {
        log(level: .error, message: message)
    }

    /// Logs a message at the specified level.
    public func log(level: BLELogLevel, message: String) {
        queue.async { [weak self] in
            self?.performLog(level: level, message: message)
        }
    }
    
    // MARK: - Private Implementation
    
    private func performLog(level: BLELogLevel, message: String) {
        guard _isEnabled && level.rawValue >= _minimumLogLevel.rawValue else {
            return
        }
        
        let formattedMessage = formatMessage(level: level, message: message)
        
        print(formattedMessage)
        
        if _useSystemLogging {
            let osLogType: OSLogType
            switch level {
            case .debug:
                osLogType = .debug
            case .info:
                osLogType = .info
            case .warning:
                osLogType = .default
            case .error:
                osLogType = .error
            }
            
            os_log("%{public}@", log: osLog, type: osLogType, formattedMessage)
        }
    }
    
    private func formatMessage(level: BLELogLevel, message: String) -> String {
        var components: [String] = []
        
        components.append(_prefix)
        
        if _includeTimestamp {
            let timestamp = timestampFormatter.string(from: Date())
            components.append("[\(timestamp)]")
        }
        
        components.append("[\(level.description)]")
        components.append(message)
        
        return components.joined(separator: "")
    }
}

// MARK: - Convenience Extensions

public extension BLELogger {

    /// Configures the logger for debug/development builds.
    func enableDebugLogging() {
        minimumLogLevel = .debug
    }

    /// Configures the logger for production builds.
    func enableProductionLogging() {
        minimumLogLevel = .error
        useSystemLogging = true
    }

    /// Completely disables all logging output.
    func disableLogging() {
        isEnabled = false
    }

    /// Resets all logging configuration to default values.
    func resetToDefaults() {
        isEnabled = true
        minimumLogLevel = .debug
        includeTimestamp = true
        prefix = "[BLEKit]"
        useSystemLogging = false
    }

    var configurationDescription: String {
        return """
        BLELogger Configuration:
        - Enabled: \(isEnabled)
        - Minimum Level: \(minimumLogLevel)
        - Include Timestamp: \(includeTimestamp)
        - Prefix: \(prefix)
        - System Logging: \(useSystemLogging)
        """
    }
}
