//
//  MockPumpManager.swift
//  LoopKit
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit
import LoopTestingKit

public protocol MockPumpManagerStateObserver {
    func mockPumpManager(_ manager: MockPumpManager, didUpdate state: MockPumpManagerState)
    func mockPumpManager(_ manager: MockPumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus)
}

public enum MockPumpManagerError: LocalizedError {
    case pumpSuspended
    case communicationFailure
    case bolusInProgress
    case missingSettings
    

    public var failureReason: String? {
        switch self {
        case .pumpSuspended:
            return "Pump is suspended"
        case .communicationFailure:
            return "Unable to communicate with pump"
        case .bolusInProgress:
            return "Bolus in progress"
        case .missingSettings:
            return "Missing Settings"
        }
    }
}

public final class MockPumpManager: TestingPumpManager {

    public static let managerIdentifier = "MockPumpManager"
    public static let localizedTitle = "Simulator"
    
    private static let device = HKDevice(
        name: MockPumpManager.managerIdentifier,
        manufacturer: nil,
        model: nil,
        hardwareVersion: nil,
        firmwareVersion: nil,
        softwareVersion: String(LoopKitVersionNumber),
        localIdentifier: nil,
        udiDeviceIdentifier: nil
    )

    private static let deliveryUnitsPerMinute = 1.5
    private static let pulsesPerUnit: Double = 20
    private static let pumpReservoirCapacity: Double = 200

    public var pumpReservoirCapacity: Double {
        return MockPumpManager.pumpReservoirCapacity
    }

    public var reservoirFillFraction: Double {
        get {
            return state.reservoirUnitsRemaining / pumpReservoirCapacity
        }
        set {
            state.reservoirUnitsRemaining = newValue * pumpReservoirCapacity
        }
    }

    public var supportedBolusVolumes: [Double] {
        return supportedBasalRates
    }

    public var supportedBasalRates: [Double] {
        return (0...700).map { Double($0) / Double(type(of: self).pulsesPerUnit) }
    }

    public var maximumBasalScheduleEntryCount: Int {
        return 48
    }

    public var minimumBasalScheduleEntryDuration: TimeInterval {
        return .minutes(30)
    }

    public var testingDevice: HKDevice {
        return type(of: self).device
    }

    public var lastReconciliation: Date? {
        return Date()
    }

    private func basalDeliveryState(for state: MockPumpManagerState) -> PumpManagerStatus.BasalDeliveryState {
        if case .suspended(let date) = state.suspendState {
            return .suspended(date)
        }
        if let temp = state.unfinalizedTempBasal, !temp.finished {
            return .tempBasal(DoseEntry(temp))
        }
        if case .resumed(let date) = state.suspendState {
            return .active(date)
        } else {
            return .active(Date())
        }
    }

    private func bolusState(for state: MockPumpManagerState) -> PumpManagerStatus.BolusState {
        if let bolus = state.unfinalizedBolus, !bolus.finished {
            return .inProgress(DoseEntry(bolus))
        } else {
            return .none
        }
    }

    private func status(for state: MockPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: .current,
            device: MockPumpManager.device,
            pumpBatteryChargeRemaining: state.pumpBatteryChargeRemaining,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state)
        )
    }

    public var pumpBatteryChargeRemaining: Double? {
        get {
            return state.pumpBatteryChargeRemaining
        }
        set {
            state.pumpBatteryChargeRemaining = newValue
        }
    }

    public var status: PumpManagerStatus {
        get {
            return status(for: self.state)
        }
    }

    private func notifyObservers() {
    }

    public var state: MockPumpManagerState {
        didSet {
            let newValue = state

            let oldStatus = status(for: oldValue)
            let newStatus = status(for: newValue)

            if oldStatus != newStatus {
                statusObservers.forEach { $0.pumpManager(self, didUpdate: newStatus, oldStatus: oldStatus) }
            }

            stateObservers.forEach { $0.mockPumpManager(self, didUpdate: self.state) }

            delegate.notify { (delegate) in
                if newValue.reservoirUnitsRemaining != oldValue.reservoirUnitsRemaining {
                    delegate?.pumpManager(self, didReadReservoirValue: self.state.reservoirUnitsRemaining, at: Date()) { result in
                        // nothing to do here
                    }
                }
                delegate?.pumpManagerDidUpdateState(self)
            }
        }
    }

    public var pumpManagerDelegate: PumpManagerDelegate? {
        get {
            return delegate.delegate
        }
        set {
            delegate.delegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return delegate.queue
        }
        set {
            delegate.queue = newValue
        }
    }

    private let delegate = WeakSynchronizedDelegate<PumpManagerDelegate>()

    private var statusObservers = WeakSynchronizedSet<PumpManagerStatusObserver>()
    private var stateObservers = WeakSynchronizedSet<MockPumpManagerStateObserver>()

    public init() {
        state = MockPumpManagerState(
            reservoirUnitsRemaining: MockPumpManager.pumpReservoirCapacity,
            tempBasalEnactmentShouldError: false,
            bolusEnactmentShouldError: false,
            deliverySuspensionShouldError: false,
            deliveryResumptionShouldError: false,
            maximumBolus: 25.0,
            maximumBasalRatePerHour: 5.0,
            suspendState: .resumed(Date()),
            pumpBatteryChargeRemaining: 1,
            unfinalizedBolus: nil,
            unfinalizedTempBasal: nil,
            finalizedDoses: [])
    }

    public init?(rawState: RawStateValue) {
        guard let state = (rawState["state"] as? MockPumpManagerState.RawValue).flatMap(MockPumpManagerState.init(rawValue:)) else {
            return nil
        }
        self.state = state
    }

    public var rawState: RawStateValue {
        return ["state": state.rawValue]
    }

    public func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter? {
        if case .inProgress(let dose) = status.bolusState {
            return MockDoseProgressEstimator(reportingQueue: dispatchQueue, dose: dose)
        }
        return nil
    }

    public var pumpRecordsBasalProfileStartEvents: Bool {
        return false
    }

    public func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue) {
        statusObservers.insert(observer, queue: queue)
    }

    public func addStateObserver(_ observer: MockPumpManagerStateObserver, queue: DispatchQueue) {
        stateObservers.insert(observer, queue: queue)
    }

    public func removeStatusObserver(_ observer: PumpManagerStatusObserver) {
        statusObservers.removeElement(observer)
    }

    public func assertCurrentPumpData() {

        state.finalizeFinishedDoses()

        storeDoses { (error) in
            self.delegate.notify { (delegate) in
                delegate?.pumpManagerRecommendsLoop(self)
            }

            guard error == nil else {
                return
            }

            DispatchQueue.main.async {
                let totalInsulinUsage = self.state.finalizedDoses.reduce(into: 0 as Double) { total, dose in
                    total += dose.units
                }

                self.state.finalizedDoses = []
                self.state.reservoirUnitsRemaining -= totalInsulinUsage
            }
        }
    }

    private func storeDoses(completion: @escaping (_ error: Error?) -> Void) {
        state.finalizeFinishedDoses()
        let pendingPumpEvents = state.dosesToStore.map { NewPumpEvent($0) }
        delegate.notify { (delegate) in
            delegate?.pumpManager(self, hasNewPumpEvents: pendingPumpEvents, lastReconciliation: self.lastReconciliation) { error in
                completion(error)
            }
        }
    }

    public func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {
        logDeviceComms(.send, message: "Temp Basal \(unitsPerHour) U/hr Duration:\(duration.hours)")

        if state.tempBasalEnactmentShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Temp Basal failed with error \(error)")
            completion(.failure(error))
        } else {
            let now = Date()
            if let temp = state.unfinalizedTempBasal, temp.finishTime.compare(now) == .orderedDescending {
                state.unfinalizedTempBasal?.cancel(at: now)
            }
            state.finalizeFinishedDoses()

            logDeviceComms(.receive, message: "Temp Basal succeeded")

            if duration < .ulpOfOne {
                // Cancel temp basal
                let temp = UnfinalizedDose(tempBasalRate: unitsPerHour, startTime: now, duration: duration)
                storeDoses { (error) in
                    completion(.success(DoseEntry(temp)))
                }
            } else {
                let temp = UnfinalizedDose(tempBasalRate: unitsPerHour, startTime: now, duration: duration)
                state.unfinalizedTempBasal = temp
                storeDoses { (error) in
                    completion(.success(DoseEntry(temp)))
                }
            }
        }
    }
    
    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockpump", type: type, message: message, completion: nil)
        }
    }

    public func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (DoseEntry) -> Void, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {

        logDeviceComms(.send, message: "Bolus \(units) U")

        if state.bolusEnactmentShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Bolus failed with error \(error)")
            completion(.failure(SetBolusError.certain(error)))
        } else {

            state.finalizeFinishedDoses()

            if let _ = state.unfinalizedBolus {
                completion(.failure(SetBolusError.certain(PumpManagerError.deviceState(MockPumpManagerError.bolusInProgress))))
                return
            }

            if case .suspended = status.basalDeliveryState {
                completion(.failure(SetBolusError.certain(PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended))))
                return
            }
            
            
            let bolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), duration: .minutes(units / type(of: self).deliveryUnitsPerMinute))
            let dose = DoseEntry(bolus)
            willRequest(dose)
            state.unfinalizedBolus = bolus
            
            logDeviceComms(.receive, message: "Bolus accepted")
            
            storeDoses { (error) in
                completion(.success(dose))
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {

        state.unfinalizedBolus?.cancel(at: Date())

        storeDoses { (_) in
            DispatchQueue.main.async {
                self.state.finalizeFinishedDoses()
                completion(.success(nil))
            }
        }
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        // nothing to do here
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        logDeviceComms(.send, message: "Suspend")
            
        if self.state.deliverySuspensionShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Suspend failed with error: \(error)")
            completion(error)
        } else {
            let now = Date()
            state.unfinalizedTempBasal?.cancel(at: now)
            state.unfinalizedBolus?.cancel(at: now)


            let suspendDate = Date()
            let suspend = UnfinalizedDose(suspendStartTime: suspendDate)
            self.state.finalizedDoses.append(suspend)
            self.state.suspendState = .suspended(suspendDate)
            logDeviceComms(.receive, message: "Suspend accepted")

            storeDoses { (error) in
                completion(error)
            }
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        logDeviceComms(.send, message: "Resume")

        if self.state.deliveryResumptionShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Resume failed with error: \(error)")
            completion(error)
        } else {
            let resumeDate = Date()
            let resume = UnfinalizedDose(resumeStartTime: resumeDate)
            self.state.finalizedDoses.append(resume)
            self.state.suspendState = .resumed(resumeDate)
            storeDoses { (error) in
                completion(error)
            }
        }
    }

    public func injectPumpEvents(_ pumpEvents: [NewPumpEvent]) {
        state.finalizedDoses += pumpEvents.compactMap { $0.unfinalizedDose }
    }
    
    public func setMaximumTempBasalRate(_ rate: Double) { }

    public func syncBasalRateSchedule(items scheduleItems: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(500)) {
            completion(.success(BasalRateSchedule(dailyItems: scheduleItems, timeZone: self.status.timeZone)!))
        }
    }
}

// MARK: - AlertResponder implementation
extension MockPumpManager {
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) { }
}

// MARK: - AlertSoundVendor implementation
extension MockPumpManager {
    public func getSoundBaseURL() -> URL? { return nil }
    public func getSounds() -> [Alert.Sound] { return [] }
}

extension MockPumpManager {
    public var debugDescription: String {
        return """
        ## MockPumpManager
        status: \(status)
        state: \(state)
        stateObservers.count: \(stateObservers.cleanupDeallocatedElements().count)
        statusObservers.count: \(statusObservers.cleanupDeallocatedElements().count)
        """
    }
}
