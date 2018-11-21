//
//  MockPumpManager.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public protocol MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockPumpManager, didUpdateReservoirUnitsRemaining units: Double)
}

public final class MockPumpManager: PumpManager {
    public static let managerIdentifier = "MockPumpManager"
    public static let localizedTitle = "Simulator"

    private static let deliveryUnitsPerMinute = 1.5
    private static let pulsesPerUnit: Double = 20

    public var pumpReservoirCapacity: Double = 200

    public var status: PumpManagerStatus {
        didSet {
            statusObservers.forEach { $0.pumpManager(self, didUpdateStatus: status) }
        }
    }

    public var reservoirUnitsRemaining: Double? {
        didSet {
            if let reservoirUnitsRemaining = reservoirUnitsRemaining {
                stateObservers.forEach { $0.mockPumpManager(self, didUpdateReservoirUnitsRemaining: reservoirUnitsRemaining) }
                pumpManagerDelegate?.pumpManager(self, didReadReservoirValue: reservoirUnitsRemaining, at: Date()) { result in
                    // TODO: anything with the result here?
                }
            }
        }
    }

    public var maximumBasalRatePerHour: Double = 5

    public var maximumBolus: Double = 25

    public var tempBasalEnactmentShouldError = false
    public var bolusEnactmentShouldError = false
    public var deliverySuspensionShouldError = false
    public var deliveryResumptionShouldError = false

    public var pumpManagerDelegate: PumpManagerDelegate?

    private var statusObservers = WeakObserverSet<PumpManagerStatusObserver>()

    private var stateObservers = WeakObserverSet<MockPumpManagerStateObserver>()

    private var pendingPumpEvents: [NewPumpEvent] = []

    private var bleHeartbeatTimer: Timer?

    public init() {
        let device = HKDevice(name: MockPumpManager.managerIdentifier, manufacturer: nil, model: nil, hardwareVersion: nil, firmwareVersion: nil, softwareVersion: nil, localIdentifier: nil, udiDeviceIdentifier: nil)
        status = PumpManagerStatus(timeZone: .current, device: device, pumpBatteryChargeRemaining: nil, suspendState: .none, bolusState: .none)
        setupBLEHeartbeatTimer()
    }

    private func setupBLEHeartbeatTimer() {
        bleHeartbeatTimer = Timer(timeInterval: .minutes(5), repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.pumpManagerDelegate?.pumpManagerBLEHeartbeatDidFire(self)
        }
    }

    deinit {
        bleHeartbeatTimer?.invalidate()
    }

    public convenience init?(rawState: RawStateValue) {
        // TODO:
        self.init()
    }

    public var rawState: RawStateValue {
        // TODO:
        return [:]
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return false
    }

    public func addStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.add(observer)
    }

    public func addStateObserver(_ observer: MockPumpManagerStateObserver) {
        stateObservers.add(observer)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        if let stateObserver = observer as? MockPumpManagerStateObserver {
            stateObservers.remove(stateObserver)
        }
        statusObservers.remove(observer)
    }

    public func assertCurrentPumpData() {
        pumpManagerDelegate?.pumpManager(self, didReadPumpEvents: pendingPumpEvents) { [weak self] error in
            // TODO: anything with the error here?
            guard let self = self else { return }
            self.pumpManagerDelegate?.pumpManagerRecommendsLoop(self)
        }
        pendingPumpEvents.removeAll()
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        if tempBasalEnactmentShouldError {
            completion(.failure(PumpManagerError.communication))
        } else {
            let temp = NewPumpEvent.tempBasal(at: Date(), for: duration, unitsPerHour: unitsPerHour)
            pendingPumpEvents.append(temp)
            completion(.success(temp.dose!))
        }
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (Error?) -> Void) {
        if bolusEnactmentShouldError {
            completion(PumpManagerError.communication)
        } else {
            let bolus = NewPumpEvent.bolus(at: Date(), units: units, deliveryUnitsPerMinute: type(of: self).deliveryUnitsPerMinute)
            pendingPumpEvents.append(bolus)
            willRequest(bolus.dose!)
            completion(nil)
        }
    }

    public static func roundToDeliveryIncrement(_ units: Double) -> Double {
        return round(units * pulsesPerUnit) / pulsesPerUnit
    }

    public func updateBLEHeartbeatPreference() {
        // nothing to do here
    }

    public func suspendDelivery(completion: @escaping (PumpManagerResult<Bool>) -> Void) {
        if deliverySuspensionShouldError {
            completion(.failure(PumpManagerError.communication))
        } else {
            let suspend = NewPumpEvent.suspend(at: Date())
            pendingPumpEvents.append(suspend)
            status.suspendState = .suspended
            completion(.success(true))
        }
    }

    public func resumeDelivery(completion: @escaping (PumpManagerResult<Bool>) -> Void) {
        if deliveryResumptionShouldError {
            completion(.failure(PumpManagerError.communication))
        } else {
            let resume = NewPumpEvent.resume(at: Date())
            pendingPumpEvents.append(resume)
            status.suspendState = .none
            completion(.success(true))
        }
    }

    public func deletePumpData(completion: @escaping (Error?) -> Void) {
        pumpManagerDelegate?.dataStore(for: self).deleteInsulinDoses(fromDevice: status.device, completion: completion)
    }
}

extension MockPumpManager {
    public var debugDescription: String {
        // TODO:
        return ""
    }
}

private extension NewPumpEvent {
    static func bolus(at date: Date, units: Double, deliveryUnitsPerMinute: Double) -> NewPumpEvent {
        let dose = DoseEntry(
            type: .bolus,
            startDate: date,
            endDate: date.addingTimeInterval(.minutes(units / deliveryUnitsPerMinute)),
            value: units,
            unit: .units
        )
        return NewPumpEvent(date: date, dose: dose, isMutable: false, raw: Data(), title: "Bolus", type: .bolus)
    }

    static func tempBasal(at date: Date, for duration: TimeInterval, unitsPerHour: Double) -> NewPumpEvent {
        let dose = DoseEntry(
            type: .basal,
            startDate: date,
            endDate: date.addingTimeInterval(duration),
            value: unitsPerHour,
            unit: .unitsPerHour
        )
        return NewPumpEvent(date: date, dose: dose, isMutable: false, raw: Data(), title: "Temp Basal", type: .tempBasal)
    }

    static func suspend(at date: Date) -> NewPumpEvent {
        let dose = DoseEntry(suspendDate: date)
        return NewPumpEvent(date: date, dose: dose, isMutable: false, raw: Data(), title: "Suspend", type: .suspend)
    }

    static func resume(at date: Date) -> NewPumpEvent {
        let dose = DoseEntry(resumeDate: date)
        return NewPumpEvent(date: date, dose: dose, isMutable: false, raw: Data(), title: "Resume", type: .resume)
    }
}

private extension PumpManagerError {
    static var communication: PumpManagerError {
        return .communication(nil)
    }
}
