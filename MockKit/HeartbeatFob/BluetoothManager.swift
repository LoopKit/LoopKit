//
//  BluetoothManager.swift
//  MockKit
//
//  Created by Pete Schwamb on 4/3/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreBluetooth
import Foundation
import os.log
import LoopKit

protocol BluetoothManagerDelegate: AnyObject {

    /**
     Tells the delegate that the bluetooth manager has finished connecting to and discovering all required services of its peripheral

     - parameter manager: The bluetooth manager
     - parameter peripheralManager: The peripheral manager
     - parameter error:   An error describing why bluetooth setup failed

     - returns: True if scanning should stop
     */
    func bluetoothManager(_ manager: BluetoothManager, readied peripheralManager: PeripheralManager) async

    /**
     Tells the delegate that the bluetooth manager encountered an error while connecting to and discovering required services of a peripheral

     - parameter manager: The bluetooth manager
     - parameter peripheralManager: The peripheral manager
     - parameter error:   An error describing why bluetooth setup failed
     */
    func bluetoothManager(_ manager: BluetoothManager, readyingFailed peripheralManager: PeripheralManager, with error: Error)

    /**
     Asks the delegate if the discovered or restored peripheral is active or should be connected to

     - parameter manager:    The bluetooth manager
     - parameter peripheral: The found peripheral

     - returns: PeripheralConnectionCommand indicating what should be done with this peripheral
     */
    func bluetoothManager(_ manager: BluetoothManager, shouldConnectPeripheral peripheral: CBPeripheral) async -> Bool

    /// Informs the delegate that the bluetooth manager received a new hearbeat value
    ///
    /// - Parameters:
    ///   - manager: The bluetooth manager
    ///   - peripheralManager: The peripheral manager
    ///   - response: The data received on the control characteristic
    func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveHeartbeat response: Data)

    /// Informs the delegate that the bluetooth manager received a new battery level value
    ///
    /// - Parameters:
    ///   - manager: The bluetooth manager
    ///   - peripheralManager: The peripheral manager
    ///   - response: The data received on the control characteristic
    func bluetoothManager(_ manager: BluetoothManager, peripheralManager: PeripheralManager, didReceiveBatteryLevel response: Data)

    /// Informs the delegate that the bluetooth manager started or stopped scanning
    ///
    /// - Parameters:
    ///   - manager: The bluetooth manager
    func bluetoothManagerScanningStatusDidChange(_ manager: BluetoothManager)

    /// Informs the delegate that a peripheral disconnected
    ///
    /// - Parameters:
    ///   - manager: The bluetooth manager
    func peripheralDidDisconnect(_ manager: BluetoothManager, peripheralManager: PeripheralManager, wasRemoteDisconnect: Bool)
}

@MainActor
class BluetoothManager: NSObject {

    weak var delegate: BluetoothManagerDelegate?

    private let log = OSLog(category: "BluetoothManager")

    /// Isolated to `managerQueue`
    private var centralManager: CBCentralManager! = nil

    /// Isolated to `managerQueue`
    private var discoveredPeripherals: Set<CBPeripheral> = []

    /// Isolated to `managerQueue`
    private var peripheral: CBPeripheral? {
        get {
            return peripheralManager?.peripheral
        }
    }

    /// Isolated to `managerQueue`
    private var isScanningEnabled = false

    var peripheralIdentifier: UUID? {
        get {
            return lockedPeripheralIdentifier.value
        }
    }
    private let lockedPeripheralIdentifier: Locked<UUID?>

    /// Isolated to `managerQueue`
    private var peripheralManager: PeripheralManager? {
        didSet {
            oldValue?.delegate = nil
            lockedPeripheralIdentifier.value = peripheralManager?.peripheral.identifier
        }
    }

    // MARK: - Synchronization

    private let managerQueue = DispatchQueue(label: "org.loopkit.HeartbeatFob.bluetoothManagerQueue", qos: .unspecified)

    init(peripheralIdentifier: UUID?) {
        self.lockedPeripheralIdentifier = Locked(peripheralIdentifier)
        super.init()

        managerQueue.sync {
            self.centralManager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: "org.loopkit.HeartbeatFob"])
        }
    }

    // MARK: - Actions

    func triggerBatteryRead() {
        peripheralManager?.readBatteryLevel()
    }

    func forgetPeripheral() {
        managerQueue.sync {
            self.peripheralManager = nil
        }
    }

    func stopScanning() {
        managerQueue.sync {
            managerQueue_stopScanning()
        }
    }

    private func managerQueue_stopScanning() {
        if centralManager.isScanning {
            log.debug("Stopping scan")
            centralManager.stopScan()
            delegate?.bluetoothManagerScanningStatusDidChange(self)
        }
    }

    func disconnect() {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))

        managerQueue.sync {
            if let peripheral = peripheral {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }
    }

    public func setScanningEnabled(_ enabled: Bool) {
        log.debug("Set scanning enabled: %{public}@", String(describing: enabled))
        managerQueue.sync {
            self.isScanningEnabled = enabled

            if case .poweredOn = self.centralManager.state {
                if enabled {
                    self.managerQueue_scanForPeripheral()
                } else if self.centralManager.isScanning {
                    self.centralManager.stopScan()
                }
            }
        }
    }


    private func managerQueue_scanForPeripheral() {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        guard centralManager.state == .poweredOn else {
            return
        }

        log.debug("Scanning for peripherals")
        centralManager.scanForPeripherals()
        delegate?.bluetoothManagerScanningStatusDidChange(self)
    }

    // MARK: - Accessors

    var isScanning: Bool {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))

        var isScanning = false
        managerQueue.sync {
            isScanning = centralManager.isScanning
        }
        return isScanning
    }

    var isConnected: Bool {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))

        var isConnected = false
        managerQueue.sync {
            isConnected = peripheral?.state == .connected
        }
        return isConnected
    }

    private func handleDiscoveredPeripheral(_ peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        discoveredPeripherals.insert(peripheral)

        connectToPeripheralIfSelected(peripheral)
    }

    private func connectToPeripheralIfSelected(_ peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        if let delegate = delegate {
            Task {
                if await delegate.bluetoothManager(self, shouldConnectPeripheral: peripheral) {
                    log.debug("Making peripheral active: %{public}@", peripheral.identifier.uuidString)

                    if let peripheralManager {
                        peripheralManager.peripheral = peripheral
                    } else {
                        peripheralManager = PeripheralManager(
                            peripheral: peripheral,
                            configuration: .heartbeatFob,
                            centralManager: centralManager
                        )
                        peripheralManager?.delegate = self
                    }
                    self.centralManager.connect(peripheral)
                }
            }
        }
    }

    override var debugDescription: String {
        return [
            "## BluetoothManager",
            peripheralManager.map(String.init(reflecting:)) ?? "No peripheral",
        ].joined(separator: "\n")
    }
}


extension CBCentralManager {
    func scanForPeripherals(withOptions options: [String: Any]? = nil) {
        scanForPeripherals(withServices: [HeartbeatFobUUID.heartbeatService.cbUUID], options: options)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        peripheralManager?.centralManagerDidUpdateState(central)
        log.default("%{public}@: %{public}@", #function, String(describing: central.state.rawValue))

        switch central.state {
        case .poweredOn:
            if let peripheralID = peripheralIdentifier, let peripheral = centralManager.retrievePeripherals(withIdentifiers: [peripheralID]).first {
                log.debug("Retrieved peripheral %{public}@", peripheral.identifier.uuidString)
                handleDiscoveredPeripheral(peripheral)
            } else {
                for peripheral in centralManager.retrieveConnectedPeripherals(withServices: [
                    HeartbeatFobUUID.heartbeatService.cbUUID
                ]) {
                    handleDiscoveredPeripheral(peripheral)
                }
            }

            if isScanningEnabled {
                managerQueue_scanForPeripheral()
            }
        case .resetting, .poweredOff, .unauthorized, .unknown, .unsupported:
            fallthrough
        @unknown default:
            if central.isScanning {
                log.debug("Stopping scan on central not powered on")
                central.stopScan()
                delegate?.bluetoothManagerScanningStatusDidChange(self)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                log.default("Restoring peripheral %{public}@ from state: %{public}@", peripheral.name ?? "Unknown", peripheral.identifier.uuidString)
                handleDiscoveredPeripheral(peripheral)
            }
        }
    }

    func peripheralSelectionDidChange() {

        disconnect()

        managerQueue.async {
            for peripheral in self.discoveredPeripherals {
                self.connectToPeripheralIfSelected(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        log.info("%{public}@: %{public}@, data = %{public}@", #function, peripheral, String(describing: advertisementData))

        managerQueue.async {
            self.handleDiscoveredPeripheral(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        log.default("%{public}@: %{public}@", #function, peripheral)

        if let peripheralManager, peripheralManager.peripheral == peripheral {
            peripheralManager.centralManager(central, didConnect: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))
        log.default("%{public}@: %{public}@", #function, peripheral)
        // Ignore errors indicating the peripheral disconnected remotely, as that's expected behavior
        if let error = error as NSError?, CBError(_nsError: error).code != .peripheralDisconnected {
            log.error("%{public}@: %{public}@", #function, error)
            if let peripheralManager = peripheralManager {
                self.delegate?.bluetoothManager(self, readyingFailed: peripheralManager, with: error)
            }
        }

        if let peripheralManager, peripheralManager.peripheral == peripheral {
            let remoteDisconnect: Bool
            if let error = error as NSError?, CBError(_nsError: error).code == .peripheralDisconnected {
                remoteDisconnect = true
            } else {
                remoteDisconnect = false
            }
            self.delegate?.peripheralDidDisconnect(self, peripheralManager: peripheralManager, wasRemoteDisconnect: remoteDisconnect)

        }

        connectToPeripheralIfSelected(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        log.error("%{public}@: %{public}@", #function, String(describing: error))
        if let error = error, let peripheralManager = peripheralManager {
            self.delegate?.bluetoothManager(self, readyingFailed: peripheralManager, with: error)
        }
    }
}


extension BluetoothManager: PeripheralManagerDelegate {
    func peripheralManager(_ manager: PeripheralManager, didReadRSSI RSSI: NSNumber, error: Error?) {

    }

    func peripheralManagerDidUpdateName(_ manager: PeripheralManager) {
    }

    func peripheralManagerDidConnect(_ manager: PeripheralManager) {
    }

    func completeConfiguration(for manager: PeripheralManager) throws {
        Task {
            await delegate?.bluetoothManager(self, readied: manager)
        }
    }

    func peripheralManager(_ manager: PeripheralManager, didUpdateValueFor characteristic: CBCharacteristic) {
        guard let value = characteristic.value else {
            return
        }

        if let heartbeatCharacteristic = HeartbeatServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString.uppercased()) {
            switch heartbeatCharacteristic {
            case .value:
                self.delegate?.bluetoothManager(self, peripheralManager: manager, didReceiveHeartbeat: value)
            default:
                return
            }
        }

        if let batteryCharacteristic = BatteryServiceCharacteristicUUID(rawValue: characteristic.uuid.uuidString.uppercased()) {
            switch batteryCharacteristic {
            case .batteryLevel:
                self.delegate?.bluetoothManager(self, peripheralManager: manager, didReceiveBatteryLevel: value)
            }
        }
    }
}
