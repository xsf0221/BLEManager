//
//  BLEDeviceListViewController.swift
//  BLEKitDemo
//
//  Created by sf Hsing on 9/18/25.
//

import UIKit
import BLEKit
import CoreBluetooth
import Combine

class BLEDeviceListViewController: UIViewController {
    
    // MARK: - UI Elements
    private var bluetoothStatusView = UIView()
    private var bluetoothStatusLabel = UILabel()
    private var bluetoothStatusIndicator = UIView()
    private var deviceCountLabel = UILabel()
    private var controlButtonsStackView = UIStackView()
    private var scanButton = UIButton(type: .system)
    private var tableView = UITableView(frame: .zero, style: .plain)
    private var emptyStateView = UIView()
    private var emptyStateImageView = UIImageView()
    private var emptyStateLabel = UILabel()
    
    // MARK: - Properties
    private var devices: [BLEPeripheral] = []
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupBLEManager()
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshDeviceList()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        title = "BLE Devices"
        view.backgroundColor = UIColor.systemBackground
        
        // Create UI elements programmatically
        setupUIElements()
        setupConstraints()
        
        // Navigation bar
        navigationItem.title = "BLE Devices"
        
    }
    
    private func setupUIElements() {
        // Bluetooth Status Container
        bluetoothStatusView.backgroundColor = UIColor.systemGray6
        bluetoothStatusView.layer.cornerRadius = 12
        bluetoothStatusView.translatesAutoresizingMaskIntoConstraints = false
        
        // Bluetooth Status Indicator
        bluetoothStatusIndicator.layer.cornerRadius = 6
        bluetoothStatusIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        // Bluetooth Status Label
        bluetoothStatusLabel.text = "Bluetooth: Unknown"
        bluetoothStatusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        bluetoothStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Device Count Label
        deviceCountLabel.text = "0 devices"
        deviceCountLabel.font = UIFont.systemFont(ofSize: 12)
        deviceCountLabel.textColor = UIColor.secondaryLabel
        deviceCountLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Scan Button
        scanButton.setTitle("Start Scanning", for: .normal)
        scanButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        scanButton.backgroundColor = UIColor.systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 8
        scanButton.addTarget(self, action: #selector(scanButtonTapped), for: .touchUpInside)
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Table View
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Empty State View
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        
        emptyStateImageView.image = UIImage(systemName: "antenna.radiowaves.left.and.right.slash")
        emptyStateImageView.tintColor = UIColor.systemGray
        emptyStateImageView.contentMode = .scaleAspectFit
        emptyStateImageView.translatesAutoresizingMaskIntoConstraints = false

        emptyStateLabel.text = "No devices found"
        emptyStateLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        emptyStateLabel.textColor = UIColor.secondaryLabel
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        // Add subviews
        view.addSubview(bluetoothStatusView)
        view.addSubview(scanButton)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)

        bluetoothStatusView.addSubview(bluetoothStatusIndicator)
        bluetoothStatusView.addSubview(bluetoothStatusLabel)
        bluetoothStatusView.addSubview(deviceCountLabel)
        
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            // Bluetooth Status View
            bluetoothStatusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            bluetoothStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bluetoothStatusView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bluetoothStatusView.heightAnchor.constraint(equalToConstant: 50),
            
            // Bluetooth Status Indicator
            bluetoothStatusIndicator.centerYAnchor.constraint(equalTo: bluetoothStatusView.centerYAnchor),
            bluetoothStatusIndicator.leadingAnchor.constraint(equalTo: bluetoothStatusView.leadingAnchor, constant: 12),
            bluetoothStatusIndicator.widthAnchor.constraint(equalToConstant: 12),
            bluetoothStatusIndicator.heightAnchor.constraint(equalToConstant: 12),
            
            // Bluetooth Status Label
            bluetoothStatusLabel.centerYAnchor.constraint(equalTo: bluetoothStatusView.centerYAnchor, constant: -6),
            bluetoothStatusLabel.leadingAnchor.constraint(equalTo: bluetoothStatusIndicator.trailingAnchor, constant: 8),
            
            // Device Count Label
            deviceCountLabel.topAnchor.constraint(equalTo: bluetoothStatusLabel.bottomAnchor, constant: 2),
            deviceCountLabel.leadingAnchor.constraint(equalTo: bluetoothStatusIndicator.trailingAnchor, constant: 8),
            deviceCountLabel.trailingAnchor.constraint(equalTo: bluetoothStatusView.trailingAnchor, constant: -12),
            
            // Scan Button
            scanButton.topAnchor.constraint(equalTo: bluetoothStatusView.bottomAnchor, constant: 16),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scanButton.heightAnchor.constraint(equalToConstant: 40),

            // Table View
            tableView.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Empty State View
            emptyStateView.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 16),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Empty State Image View
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.centerYAnchor.constraint(equalTo: emptyStateView.centerYAnchor, constant: -30),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 80),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Empty State Label
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 16),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -40)
        ])
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(DeviceTableViewCell.self, forCellReuseIdentifier: "DeviceCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.separatorStyle = .singleLine
    }
    
    private func setupBLEManager() {
        // Configure BLEManager first
        BLEManager.shared.configure(with: .default)

        // Subscribe to Bluetooth state changes
        BLEManager.shared.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateBluetoothStatus()
                self?.updateScanButton()
                self?.updateEmptyState()
            }
            .store(in: &cancellables)
        
        // Subscribe to discovered peripherals list changes
        BLEManager.shared.$discoveredPeripherals
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripherals in
                self?.devices = peripherals
                self?.refreshDeviceList()
            }
            .store(in: &cancellables)
        
        // Subscribe to device connection events
        BLEManager.shared.deviceConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripheral in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // Subscribe to device disconnection events
        BLEManager.shared.deviceDisconnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        // Subscribe to connection failures
        BLEManager.shared.deviceConnectionFailed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                let (peripheral, error) = result
                let alert = UIAlertController(
                    title: "Connection Failed",
                    message: "Failed to connect to \(peripheral.name ?? "device"): \(error?.localizedDescription ?? "Unknown error")",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
            .store(in: &cancellables)
        
    }
    
    // MARK: - Actions
    
    
    @objc private func scanButtonTapped() {
        if BLEManager.shared.isScanning {
            BLEManager.shared.stopScanning()
        } else {
            do { 
                try BLEManager.shared.startScanning() 
            } catch { 
                print("Start scanning failed: \(error)") 
            }
        }
        updateScanButton()
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        updateBluetoothStatus()
        updateScanButton()
        updateDeviceCount()
        updateEmptyState()
    }
    
    private func updateBluetoothStatus() {
        let state = BLEManager.shared.bluetoothState
        let statusText: String
        let indicatorColor: UIColor
        
        switch state {
        case .poweredOn:
            statusText = "Bluetooth: Powered On"
            indicatorColor = .systemGreen
        case .poweredOff:
            statusText = "Bluetooth: Powered Off"
            indicatorColor = .systemRed
        case .unauthorized:
            statusText = "Bluetooth: Unauthorized"
            indicatorColor = .systemRed
        case .unsupported:
            statusText = "Bluetooth: Unsupported"
            indicatorColor = .systemRed
        case .resetting:
            statusText = "Bluetooth: Resetting"
            indicatorColor = .systemOrange
        case .unknown:
            statusText = "Bluetooth: Unknown"
            indicatorColor = .systemGray
        @unknown default:
            statusText = "Bluetooth: Unknown"
            indicatorColor = .systemGray
        }
        
        bluetoothStatusLabel.text = statusText
        bluetoothStatusIndicator.backgroundColor = indicatorColor
        
        // Enable/disable buttons based on Bluetooth state
        let isEnabled = state == .poweredOn
        scanButton.isEnabled = isEnabled
        scanButton.backgroundColor = isEnabled ? .systemBlue : .systemGray
    }
    
    private func updateScanButton() {
        if BLEManager.shared.isScanning {
            scanButton.setTitle("Stop Scanning", for: .normal)
            scanButton.backgroundColor = .systemRed
        } else {
            scanButton.setTitle("Start Scanning", for: .normal)
            scanButton.backgroundColor = BLEUtilities.isBluetoothReady(BLEManager.shared.bluetoothState) ? .systemBlue : .systemGray
        }
    }
    
    private func updateDeviceCount() {
        let count = devices.count
        deviceCountLabel.text = "\(count) device\(count == 1 ? "" : "s")"
    }
    
    private func updateEmptyState() {
        let isEmpty = devices.isEmpty
        tableView.isHidden = isEmpty
        emptyStateView.isHidden = !isEmpty
        
        if isEmpty {
            if BLEManager.shared.isScanning {
                emptyStateLabel.text = "Scanning for devices..."
                emptyStateImageView.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
            } else if !BLEUtilities.isBluetoothReady(BLEManager.shared.bluetoothState) {
                emptyStateLabel.text = "Please enable Bluetooth to scan for devices"
                emptyStateImageView.image = UIImage(systemName: "antenna.radiowaves.left.and.right.slash")
            } else {
                emptyStateLabel.text = "No devices found\nTap 'Start Scanning' to discover BLE devices"
                emptyStateImageView.image = UIImage(systemName: "antenna.radiowaves.left.and.right.slash")
            }
        }
    }
    
    private func refreshDeviceList() {
        devices = BLEManager.shared.discoveredPeripherals.sorted(by: { lhs, rhs in
            lhs.rssi.intValue > rhs.rssi.intValue
        })
        tableView.reloadData()
        updateDeviceCount()
        updateEmptyState()
    }
}

// MARK: - UITableViewDataSource
extension BLEDeviceListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath) as! DeviceTableViewCell
        let device = devices[indexPath.row]
        let isConnected = BLEUtilities.isDeviceConnected(device)
        cell.configure(with: device, isConnected: isConnected)
        cell.delegate = self
        return cell
    }
}

// MARK: - UITableViewDelegate
extension BLEDeviceListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - DeviceTableViewCellDelegate
extension BLEDeviceListViewController: DeviceTableViewCellDelegate {
    func deviceCell(_ cell: DeviceTableViewCell, didTapConnectForDevice device: BLEPeripheral) {
        if BLEUtilities.isDeviceConnected(device) {
            do {
                try BLEManager.shared.disconnect(from: device)
            } catch {
                print("Disconnect failed: \(error)")
            }
        } else {
            do {
                try BLEManager.shared.connect(to: device)
            } catch {
                print("Connect failed: \(error)")
            }
        }
        
        // Refresh the specific cell
        if let indexPath = tableView.indexPath(for: cell) {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}

