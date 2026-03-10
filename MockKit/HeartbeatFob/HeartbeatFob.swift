//
//  HeartbeatFob.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/5/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import CoreBluetooth
import HealthKit
import os.log
import Combine

public protocol HeartbeatFobDelegate: AnyObject {
    func heartbeatFobTriggeredHeartbeat(_ fob: HeartbeatFob)
    func heartbeatFobSelectionChanged(id: Int?, peripheralIdentifier: UUID?)
}

public struct DiscoveredFob: Identifiable {
    public var id: Int
    public var isSelected: Bool
    public var peripheralState: CBPeripheralState
    public var peripheralId: UUID
    public var batteryPercent: UInt8?

    public var displayName: String {
        return "Heartbeat Fob \(id)"
    }
}

@MainActor
public final class HeartbeatFob: ObservableObject, BluetoothManagerDelegate {

    @Published var pairedFobId: Int?

    @Published public var discoveredFobs: [DiscoveredFob] = []

    @Published var scanning: Bool = false

    @Published var connectionError: Error?

    public weak var delegate: HeartbeatFobDelegate?

    /// The date of last connection
    private var lastConnection: Date?

    // MARK: -

    private let log = OSLog(category: "HeartbeatFob")

    private let bluetoothManager: BluetoothManager

    private let delegateQueue = DispatchQueue(label: "com.loopkit.HeartbeatFob.delegateQueue", qos: .unspecified)

    public func toggleFobSelection(_ selectedId: Int) {

        if selectedId == self.pairedFobId {
            self.pairedFobId = nil
            bluetoothManager.disconnect()
        } else {
            self.pairedFobId = selectedId
        }

        var peripheralIdentifier: UUID?

        discoveredFobs.indices.forEach {
            if discoveredFobs[$0].id == self.pairedFobId {
                discoveredFobs[$0].isSelected = true
                peripheralIdentifier = discoveredFobs[$0].peripheralId
            } else {
                discoveredFobs[$0].isSelected = false
            }
        }

        bluetoothManager.peripheralSelectionDidChange()

        delegate?.heartbeatFobSelectionChanged(id: self.pairedFobId, peripheralIdentifier: peripheralIdentifier)
    }

    public init(fobId: Int?, peripheralIdentifier: UUID?) {
        self.pairedFobId = fobId
        bluetoothManager = BluetoothManager(peripheralIdentifier: peripheralIdentifier)
        bluetoothManager.delegate = self
    }

    public func resumeScanning() {
        bluetoothManager.setScanningEnabled(true)
    }

    public func stopScanning() {
        bluetoothManager.setScanningEnabled(false)
    }

    // MARK: - BluetoothManagerDelegate

    func bluetoothManager(_ manager: BluetoothManager, readied peripheralManager: PeripheralManager) async {
        if let pairedFobId, let fobId = extractIdFromName(peripheralManager.peripheral.name), fobId == pairedFobId {
            discoveredFobs.indices.forEach {
                if discoveredFobs[$0].id == fobId {
                    discoveredFobs[$0].peripheralState = peripheralManager.peripheral.state
                    peripheralManager.readBatteryLevel()
                }
            }
        }
    }

    public func triggerBatteryLevelRead() {
        bluetoothManager.triggerBatteryRead()
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, readyingFailed peripheralManager: PeripheralManager, with error: Error) {
        Task { @MainActor in
            connectionError = error
        }
    }

    nonisolated func peripheralDidDisconnect(_ manager: BluetoothManager, peripheralManager: PeripheralManager, wasRemoteDisconnect: Bool) {
        Task { @MainActor in
            discoveredFobs.indices.forEach {
                if discoveredFobs[$0].peripheralId == peripheralManager.peripheral.identifier {
                    discoveredFobs[$0].peripheralState = peripheralManager.peripheral.state
                }
            }
        }
    }

    func extractIdFromName(_ name: String?) -> Int? {
        guard let name else { return nil }

        if name.hasPrefix("HeartbeatFob") {
            let pattern = "\\d+$"

            // Create a regex object
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return nil
            }

            // Search for the first match
            let nsString = name as NSString
            let results = regex.matches(in: name, range: NSRange(location: 0, length: nsString.length))

            // Extract the matched substring and convert it to an Int
            if let match = results.first, let extractedId = Int(nsString.substring(with: match.range)) {
                log.debug("Mapped peripheral name %@ to fob ID %d", name, extractedId)
                return extractedId
            }
        }
        log.default("Unable to extract id from peripheral name %@", name)
        return nil

    }

    func bluetoothManager(_ manager: BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) async -> Bool {

        guard let name = peripheral.name else {
            log.debug("Not connecting to unnamed peripheral: %{public}@", String(describing: peripheral))
            return false
        }

        let index = discoveredFobs.firstIndex{ $0.peripheralId == peripheral.identifier }
        if index == nil, let newFobId = extractIdFromName(name) {
            let device = DiscoveredFob(id: newFobId, isSelected: newFobId == pairedFobId, peripheralState: peripheral.state, peripheralId: peripheral.identifier)
            discoveredFobs.append(device)
            discoveredFobs.sort(by: { $0.id < $1.id })
        }

        if let id = extractIdFromName(name) {
            return pairedFobId == id
        }


        log.info("Not connecting to peripheral: %{public}@", name)
        return false
    }

    nonisolated func bluetoothManagerScanningStatusDidChange(_ manager: BluetoothManager) {
        Task { @MainActor in
            scanning = manager.isScanning
        }
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveHeartbeat response: Data) {
        Task { @MainActor in
            self.delegate?.heartbeatFobTriggeredHeartbeat(self)
        }
    }

    nonisolated func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveBatteryLevel response: Data) {
        Task { @MainActor in
            discoveredFobs.indices.forEach {
                if discoveredFobs[$0].peripheralId == peripheralManager.peripheral.identifier {
                    log.default("Did update battery level for %@ to %@ percent.", peripheralManager.peripheral.name ?? "Unknown", String(describing: response[0]))
                    discoveredFobs[$0].batteryPercent = response[0]
                }
            }
        }
    }
}


// MARK: - Helpers
fileprivate extension PeripheralManager {
    func listenToCharacteristic(_ characteristic: HeartbeatServiceCharacteristicUUID) throws {
        try setNotifyValue(true, for: characteristic)
    }
}
