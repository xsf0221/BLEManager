//
//  DeviceTableViewCell.swift
//  BLEKitDemo
//
//  Created by sf Hsing on 9/18/25.
//

import UIKit
import BLEKit
import CoreBluetooth

protocol DeviceTableViewCellDelegate: AnyObject {
    func deviceCell(_ cell: DeviceTableViewCell, didTapConnectForDevice device: BLEPeripheral)
}

class DeviceTableViewCell: UITableViewCell {
    
    // MARK: - UI Elements
    private let deviceNameLabel = UILabel()
    private let deviceInfoLabel = UILabel()
    private let rssiLabel = UILabel()
    private let rssiIconView = UIImageView()
    private let connectButton = UIButton(type: .system)
    private let statusIndicator = UIView()
    private let manufacturerDataLabel = UILabel()
    
    // MARK: - Properties
    weak var delegate: DeviceTableViewCellDelegate?
    private var device: BLEPeripheral?
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        selectionStyle = .none
        
        // Device Name Label
        deviceNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        deviceNameLabel.numberOfLines = 1
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Device Info Label
        deviceInfoLabel.font = UIFont.systemFont(ofSize: 12)
        deviceInfoLabel.textColor = UIColor.secondaryLabel
        deviceInfoLabel.numberOfLines = 1
        deviceInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Manufacturer Data Label
        manufacturerDataLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        manufacturerDataLabel.textColor = UIColor.tertiaryLabel
        manufacturerDataLabel.numberOfLines = 1
        manufacturerDataLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // RSSI Icon
        rssiIconView.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
        rssiIconView.tintColor = UIColor.systemBlue
        rssiIconView.contentMode = .scaleAspectFit
        rssiIconView.translatesAutoresizingMaskIntoConstraints = false
        
        // RSSI Label
        rssiLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        rssiLabel.textAlignment = .right
        rssiLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Status Indicator
        statusIndicator.layer.cornerRadius = 6
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Connect Button
        connectButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        connectButton.layer.cornerRadius = 6
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        contentView.addSubview(deviceNameLabel)
        contentView.addSubview(deviceInfoLabel)
        contentView.addSubview(manufacturerDataLabel)
        contentView.addSubview(rssiIconView)
        contentView.addSubview(rssiLabel)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(connectButton)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Status Indicator
            statusIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statusIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 12),
            statusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            // Device Name Label
            deviceNameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            deviceNameLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 12),
            deviceNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: connectButton.leadingAnchor, constant: -8),
            
            // Device Info Label
            deviceInfoLabel.topAnchor.constraint(equalTo: deviceNameLabel.bottomAnchor, constant: 4),
            deviceInfoLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 12),
            deviceInfoLabel.trailingAnchor.constraint(lessThanOrEqualTo: rssiIconView.leadingAnchor, constant: -8),
            
            // Manufacturer Data Label
            manufacturerDataLabel.topAnchor.constraint(equalTo: deviceInfoLabel.bottomAnchor, constant: 4),
            manufacturerDataLabel.leadingAnchor.constraint(equalTo: statusIndicator.trailingAnchor, constant: 12),
            manufacturerDataLabel.trailingAnchor.constraint(lessThanOrEqualTo: rssiIconView.leadingAnchor, constant: -8),
            
            // RSSI Icon
            rssiIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            rssiIconView.trailingAnchor.constraint(equalTo: rssiLabel.leadingAnchor, constant: -4),
            rssiIconView.widthAnchor.constraint(equalToConstant: 16),
            rssiIconView.heightAnchor.constraint(equalToConstant: 16),
            
            // RSSI Label
            rssiLabel.centerYAnchor.constraint(equalTo: rssiIconView.centerYAnchor),
            rssiLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rssiLabel.widthAnchor.constraint(equalToConstant: 60),
            
            // Connect Button
            connectButton.topAnchor.constraint(equalTo: rssiLabel.bottomAnchor, constant: 8),
            connectButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            connectButton.widthAnchor.constraint(equalToConstant: 80),
            connectButton.heightAnchor.constraint(equalToConstant: 30),
            connectButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    // MARK: - Configuration
    func configure(with device: BLEPeripheral, isConnected: Bool) {
        self.device = device
        
        // Device name
        deviceNameLabel.text = device.name ?? "Unknown Device"
        
        // Device info (identifier)
        let shortId = String(device.identifier.uuidString.prefix(8))
        deviceInfoLabel.text = "ID: \(shortId)..."
        
        // RSSI
        let rssiValue = device.rssi.intValue
        rssiLabel.text = "\(rssiValue) dBm"
        
        // RSSI color and icon based on signal strength
        let signalStrengthIcon = getSignalStrengthIcon(rssiValue)
        rssiLabel.textColor = .systemGray
        rssiIconView.image = signalStrengthIcon
        
        // Connection status
        if isConnected {
            statusIndicator.backgroundColor = .systemGreen
            connectButton.setTitle("Disconnect", for: .normal)
            connectButton.setTitleColor(.white, for: .normal)
            connectButton.backgroundColor = .systemRed
        } else {
            statusIndicator.backgroundColor = .systemGray
            connectButton.setTitle("Connect", for: .normal)
            connectButton.setTitleColor(.white, for: .normal)
            connectButton.backgroundColor = .systemBlue
        }
        
        // Enable/disable button based on Bluetooth state
        connectButton.isEnabled = BLEUtilities.isBluetoothReady(BLEManager.shared.bluetoothState)
        if !connectButton.isEnabled {
            connectButton.backgroundColor = .systemGray
        }
    }
    
    // MARK: - Actions
    @objc private func connectButtonTapped() {
        guard let device = device else { return }
        delegate?.deviceCell(self, didTapConnectForDevice: device)
    }
    
    // MARK: - Helpers
    private func getSignalStrengthIcon(_ rssi: Int) -> UIImage? {
        switch rssi {
        case -100...0:
            return UIImage(systemName: "antenna.radiowaves.left.and.right")
        default:
            return UIImage(systemName: "antenna.radiowaves.left.and.right.slash")
        }
    }
}
