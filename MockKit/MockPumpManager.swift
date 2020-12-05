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
    case pumpError
    

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
        case .pumpError:
            return "Pump is in an error state"
        }
    }
}

public final class MockPumpManager: TestingPumpManager {

    public static let managerIdentifier = "MockPumpManager"
    public static let localizedTitle = "Insulin Pump Simulator"
    
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
    private static let pumpReservoirCapacity: Double = 200

    public var pumpReservoirCapacity: Double {
        return MockPumpManager.pumpReservoirCapacity
    }

    public var reservoirFillFraction: Double {
        get {
            return state.reservoirUnitsRemaining / pumpReservoirCapacity
        }
        set {
            state.reservoirUnitsRemaining = max(newValue * pumpReservoirCapacity, 0)
        }
    }

    public var currentBasalRate: HKQuantity? {
        switch status.basalDeliveryState {
        case .suspending, .suspended(_):
            return HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0)
        case .tempBasal(let dose):
            return HKQuantity(unit: .internationalUnitsPerHour, doubleValue: dose.unitsPerHour)
        case .none:
            return nil
        default:
            guard let scheduledBasalRate = state.basalRateSchedule?.value(at: Date()) else { return nil }

            return HKQuantity(unit: .internationalUnitsPerHour, doubleValue: scheduledBasalRate)
        }
    }

    public var supportedBolusVolumes: [Double] {
        return state.supportedBolusVolumes
    }

    public var supportedBasalRates: [Double] {
        return state.supportedBasalRates
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

    public var testLastReconciliation: Date? = nil
    
    public var lastReconciliation: Date? {
        return testLastReconciliation ?? Date()
    }

    private func basalDeliveryState(for state: MockPumpManagerState) -> PumpManagerStatus.BasalDeliveryState? {
        if case .suspended(let date) = state.suspendState {
            return .suspended(date)
        }
        if state.occlusionDetected || state.pumpErrorDetected || state.pumpBatteryChargeRemaining == 0 || state.reservoirUnitsRemaining == 0 {
            return nil
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
            return .noBolus
        }
    }
    
    private func pumpStatusHighlight(for state: MockPumpManagerState) -> PumpManagerStatus.PumpStatusHighlight? {
        if state.deliveryIsUncertain {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Comms Issue", comment: "Status highlight that delivery is uncertain."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        }
        else if state.reservoirUnitsRemaining == 0 {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("No Insulin", comment: "Status highlight that a pump is out of insulin."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        } else if state.occlusionDetected {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Pump Occlusion", comment: "Status highlight that an occlusion was detected."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        } else if state.pumpErrorDetected {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Pump Error", comment: "Status highlight that a pump error occurred."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        } else if pumpBatteryChargeRemaining == 0 {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Pump Battery Dead", comment: "Status highlight that pump has a dead battery."),
                                                         imageName: "exclamationmark.circle.fill",
                                                         state: .critical)
        } else if case .suspended = state.suspendState {
            return PumpManagerStatus.PumpStatusHighlight(localizedMessage: NSLocalizedString("Insulin Suspended", comment: "Status highlight that insulin delivery was suspended."),
                                                         imageName: "pause.circle.fill",
                                                         state: .warning)
        }
        
        return nil
    }
    
    private func pumpLifecycleProgress(for state: MockPumpManagerState) -> PumpManagerStatus.PumpLifecycleProgress? {
        guard let progressPercentComplete = state.progressPercentComplete else {
            return nil
        }
        
        let progressState: DeviceLifecycleProgressState
        if let progressCriticalThresholdPercentValue = state.progressCriticalThresholdPercentValue,
            progressPercentComplete >= progressCriticalThresholdPercentValue
        {
            progressState = .critical
        } else if let progressWarningThresholdPercentValue = state.progressWarningThresholdPercentValue,
            progressPercentComplete >= progressWarningThresholdPercentValue
        {
            progressState = .warning
        } else {
            progressState = .normalPump
        }
        
        return PumpManagerStatus.PumpLifecycleProgress(percentComplete: progressPercentComplete,
                                                       progressState: progressState)
    }

    private func status(for state: MockPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: .currentFixed,
            device: MockPumpManager.device,
            pumpBatteryChargeRemaining: state.pumpBatteryChargeRemaining,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state),
            pumpStatusHighlight: pumpStatusHighlight(for: state),
            pumpLifecycleProgress: pumpLifecycleProgress(for: state),
            deliveryIsUncertain: state.deliveryIsUncertain
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
    
    private func notifyStatusObservers(oldStatus: PumpManagerStatus) {
        let status = self.status
        delegate.notify { (delegate) in
            delegate?.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
        statusObservers.forEach { (observer) in
            observer.pumpManager(self, didUpdate: status, oldStatus: oldStatus)
        }
    }

    public var state: MockPumpManagerState {
        didSet {
            let newValue = state

            let oldStatus = status(for: oldValue)
            let newStatus = status(for: newValue)

            if oldStatus != newStatus {
                notifyStatusObservers(oldStatus: oldStatus)
            }
            
            // stop insulin delivery as pump state requires
            if (newValue.occlusionDetected != oldValue.occlusionDetected && newValue.occlusionDetected) ||
                (newValue.pumpErrorDetected != oldValue.pumpErrorDetected && newValue.pumpErrorDetected) ||
                (newValue.pumpBatteryChargeRemaining != oldValue.pumpBatteryChargeRemaining && newValue.pumpBatteryChargeRemaining == 0) ||
                (newValue.reservoirUnitsRemaining != oldValue.reservoirUnitsRemaining && newValue.reservoirUnitsRemaining == 0)
            {
                stopInsulinDelivery()
            }
            
            stateObservers.forEach { $0.mockPumpManager(self, didUpdate: self.state) }

            delegate.notify { (delegate) in
                if newValue.reservoirUnitsRemaining != oldValue.reservoirUnitsRemaining {
                    delegate?.pumpManager(self, didReadReservoirValue: self.state.reservoirUnitsRemaining, at: Date()) { result in
                        // nothing to do here
                    }
                }
                delegate?.pumpManagerDidUpdateState(self)
                
                delegate?.pumpManager(self, didUpdate: newStatus, oldStatus: oldStatus)
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
        let deliverableIncrements: MockPumpManagerState.DeliverableIncrements = .medtronicX22
        state = MockPumpManagerState(
            deliverableIncrements: deliverableIncrements,
            supportedBolusVolumes: deliverableIncrements.supportedBolusVolumes ?? [],
            supportedBasalRates: deliverableIncrements.supportedBasalRates ?? [],
            reservoirUnitsRemaining: MockPumpManager.pumpReservoirCapacity,
            tempBasalEnactmentShouldError: false,
            bolusEnactmentShouldError: false,
            bolusCancelShouldError: false,
            deliverySuspensionShouldError: false,
            deliveryResumptionShouldError: false,
            deliveryCommandsShouldTriggerUncertainDelivery: false,
            maximumBolus: 25.0,
            maximumBasalRatePerHour: 5.0,
            suspendState: .resumed(Date()),
            pumpBatteryChargeRemaining: 1,
            unfinalizedBolus: nil,
            unfinalizedTempBasal: nil,
            finalizedDoses: [],
            progressWarningThresholdPercentValue: 0.75,
            progressCriticalThresholdPercentValue: 0.9)
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
    
    private func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        self.delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "MockId", type: type, message: message, completion: nil)
        }
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

    public func ensureCurrentPumpData(completion: (() -> Void)? = nil) {
        // Change this to artificially increase the delay fetching the current pump data
        let fetchDelay = 0
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(fetchDelay)) {
            
            self.state.finalizeFinishedDoses()
            
            self.storeDoses { (error) in
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
                    self.state.reservoirUnitsRemaining = max(self.state.reservoirUnitsRemaining - totalInsulinUsage, 0)
                    
                    DispatchQueue.global().async {
                        completion?()
                    }
                }
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

        if state.tempBasalEnactmentShouldError || state.pumpBatteryChargeRemaining == 0 {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Temp Basal failed with error \(error)")
            completion(.failure(error))
        } else if state.deliveryCommandsShouldTriggerUncertainDelivery {
            state.deliveryIsUncertain = true
            logDeviceComms(.error, message: "Uncertain delivery for temp basal")
            completion(.failure(PumpManagerError.uncertainDelivery))
        } else if state.occlusionDetected || state.pumpErrorDetected {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpError)
            logDeviceComms(.error, message: "Temp Basal failed because the pump is in an error state")
            completion(.failure(error))
        } else if case .suspended = state.suspendState {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Temp Basal failed because inulin delivery is suspended")
            completion(.failure(error))
        } else if state.reservoirUnitsRemaining == 0 {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Temp Basal failed because there is no insulin in the reservoir")
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
            logDeviceCommunication("enactTempBasal succeeded", type: .receive)
        }
    }
    
    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        delegate.notify { (delegate) in
            delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockpump", type: type, message: message, completion: nil)
        }
    }

    public func enactBolus(units: Double, at startDate: Date, completion: @escaping (PumpManagerResult<DoseEntry>) -> Void) {

        logDeviceCommunication("enactBolus(\(units), \(startDate))")

        if state.bolusEnactmentShouldError || state.pumpBatteryChargeRemaining == 0 {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Bolus failed with error \(error)")
            completion(.failure(error))
        } else if state.deliveryCommandsShouldTriggerUncertainDelivery {
            state.deliveryIsUncertain = true
            logDeviceComms(.error, message: "Uncertain delivery for bolus")
            completion(.failure(PumpManagerError.uncertainDelivery))
        } else if state.occlusionDetected || state.pumpErrorDetected {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpError)
            logDeviceComms(.error, message: "Bolus failed because the pump is in an error state")
            completion(.failure(error))
        } else if state.reservoirUnitsRemaining == 0 {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Bolus failed because there is no insulin in the reservoir")
            completion(.failure(error))
        } else {
            state.finalizeFinishedDoses()

            if let _ = state.unfinalizedBolus {
                logDeviceCommunication("enactBolus failed: bolusInProgress", type: .error)
                completion(.failure(PumpManagerError.deviceState(MockPumpManagerError.bolusInProgress)))
                return
            }

            if case .suspended = status.basalDeliveryState {
                logDeviceCommunication("enactBolus failed: pumpSuspended", type: .error)
                completion(.failure(PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)))
                return
            }
            
            
            let bolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), duration: .minutes(units / type(of: self).deliveryUnitsPerMinute))
            let dose = DoseEntry(bolus)
            state.unfinalizedBolus = bolus
            
            logDeviceComms(.receive, message: "Bolus accepted")
            
            storeDoses { (error) in
                completion(.success(dose))
                self.logDeviceCommunication("enactBolus succeeded", type: .receive)
            }
        }
    }

    public func cancelBolus(completion: @escaping (PumpManagerResult<DoseEntry?>) -> Void) {
        logDeviceComms(.send, message: "Cancel")
        
        if self.state.bolusCancelShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Cancel failed with error: \(error)")
            completion(.failure(error))
        } else {
            state.unfinalizedBolus?.cancel(at: Date())
            
            storeDoses { (_) in
                DispatchQueue.main.async {
                    self.state.finalizeFinishedDoses()
                    completion(.success(nil))
                }
            }
        }
    }

    public func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool) {
        // nothing to do here
    }
    
    private func stopInsulinDelivery() {
        let now = Date()
        state.unfinalizedTempBasal?.cancel(at: now)
        state.unfinalizedBolus?.cancel(at: now)
        storeDoses { _ in }
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
            logDeviceCommunication("suspendDelivery succeeded", type: .receive)
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
            logDeviceCommunication("resumeDelivery succeeded", type: .receive)
        }
    }

    public func injectPumpEvents(_ pumpEvents: [NewPumpEvent]) {
        state.finalizedDoses += pumpEvents.compactMap { $0.unfinalizedDose }
    }
    
    public func setMaximumTempBasalRate(_ rate: Double) { }

    public func syncBasalRateSchedule(items scheduleItems: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        state.basalRateSchedule = BasalRateSchedule(dailyItems: scheduleItems, timeZone: self.status.timeZone)

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
