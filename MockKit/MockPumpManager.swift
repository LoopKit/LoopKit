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
import LoopAlgorithm

@MainActor
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
    
    public var pluginIdentifier: String { Self.managerIdentifier }
    
    public static let localizedTitle = "Pump Simulator"

    public var localizedTitle: String {
        return MockPumpManager.localizedTitle
    }

    public static var onboardingMaximumBasalScheduleEntryCount: Int {
        return 48
    }

    public static var onboardingSupportedBasalRates: [Double] {
        MockPumpManagerState.DeliverableIncrements.medtronicX22.supportedBasalRates!
    }

    public static var onboardingSupportedBolusVolumes: [Double] {
        MockPumpManagerState.DeliverableIncrements.medtronicX22.supportedBolusVolumes!
    }

    public static var onboardingSupportedMaximumBolusVolumes: [Double] {
        self.onboardingSupportedBolusVolumes
    }

    private static let device = HKDevice(
        name: MockPumpManager.managerIdentifier,
        manufacturer: nil,
        model: nil,
        hardwareVersion: nil,
        firmwareVersion: nil,
        softwareVersion: "1.0",
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

    public var currentBasalRate: LoopQuantity? {
        switch status.basalDeliveryState {
        case .suspending, .suspended(_):
            return LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: 0)
        case .tempBasal(let dose):
            return LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: dose.unitsPerHour)
        case .none:
            return nil
        default:
            guard let scheduledBasalRate = state.basalRateSchedule?.value(at: Date()) else { return nil }

            return LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: scheduledBasalRate)
        }
    }

    public var supportedBolusVolumes: [Double] {
        return state.supportedBolusVolumes
    }

    public var supportedMaximumBolusVolumes: [Double] {
        state.supportedBolusVolumes
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

    public var lastSync: Date?
    
    public var insulinType: InsulinType? {
        return state.insulinType
    }

    private func basalDeliveryState(for state: MockPumpManagerState) -> PumpManagerStatus.BasalDeliveryState? {
        if case .suspended(let date) = state.suspendState {
            return .suspended(date)
        }
        if state.occlusionDetected || state.pumpErrorDetected || state.isPumpExpired || state.pumpBatteryChargeRemaining == 0 || state.reservoirUnitsRemaining == 0 {
            return .pumpInoperable
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
    
    public func buildPumpStatusHighlight(for state: MockPumpManagerState) -> PumpStatusHighlight? {
        if state.deliveryIsUncertain {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Comms Issue", comment: "Status highlight that delivery is uncertain."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if state.reservoirUnitsRemaining == 0 {
            return PumpStatusHighlight(localizedMessage: LocalizedString("No Insulin", comment: "Status highlight that a pump is out of insulin."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if state.occlusionDetected {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Pump Occlusion", comment: "Status highlight that an occlusion was detected."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if state.pumpErrorDetected {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Pump Error", comment: "Status highlight that a pump error occurred."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if state.isPumpExpired {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Pump\nExpired", comment: "Status highlight that the pump expired."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if pumpBatteryChargeRemaining == 0 {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Pump Battery Dead", comment: "Status highlight that pump has a dead battery."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        } else if case .suspended = state.suspendState {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Insulin Suspended", comment: "Status highlight that insulin delivery was suspended."),
                                       imageName: "pause.circle.fill",
                                       state: .warning)
        } else if state.inSignalLoss {
            return PumpStatusHighlight(localizedMessage: LocalizedString("Signal Loss", comment: "Status highlight that signal is lost."),
                                       imageName: "exclamationmark.circle.fill",
                                       state: .critical)
        }
        
        return nil
    }
    
    public func buildPumpLifecycleProgress(for state: MockPumpManagerState) -> PumpLifecycleProgress? {
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
        
        return PumpLifecycleProgress(percentComplete: progressPercentComplete,
                                                       progressState: progressState)
    }
    
    public var canSynchronizePumpTime: Bool {
        detectedSystemTimeOffset == 0
    }
    
    public var detectedSystemTimeOffset: TimeInterval {
        pumpManagerDelegate?.detectedSystemTimeOffset ?? 0
    }
    
    public var isClockOffset: Bool {
        let now = Date()
        return TimeZone.current.secondsFromGMT(for: now) != state.timeZone.secondsFromGMT(for: now)
    }

    private func status(for state: MockPumpManagerState) -> PumpManagerStatus {
        return PumpManagerStatus(
            timeZone: state.timeZone,
            device: MockPumpManager.device,
            pumpBatteryChargeRemaining: state.pumpBatteryChargeRemaining,
            basalDeliveryState: basalDeliveryState(for: state),
            bolusState: bolusState(for: state),
            insulinType: state.insulinType,
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
    
    public func estimatedDuration(toBolus units: Double) -> TimeInterval {
        .minutes(units / type(of: self).deliveryUnitsPerMinute)
    }

    public var state: MockPumpManagerState {
        didSet {
            let newValue = state

            guard newValue != oldValue else {
                return
            }

            let oldStatus = status(for: oldValue)
            let newStatus = status(for: newValue)

            let oldStatusHighlight = buildPumpStatusHighlight(for: oldValue)
            let newStatusHighlight = buildPumpStatusHighlight(for: newValue)

            if oldStatus != newStatus ||
                oldStatusHighlight != newStatusHighlight
            {
                notifyStatusObservers(oldStatus: oldStatus)
            }

            // stop insulin delivery as pump state requires
            if (newValue.occlusionDetected != oldValue.occlusionDetected && newValue.occlusionDetected) ||
                (newValue.pumpErrorDetected != oldValue.pumpErrorDetected && newValue.pumpErrorDetected) ||
                (newValue.isPumpExpired != oldValue.isPumpExpired && newValue.isPumpExpired) ||
                (newValue.pumpBatteryChargeRemaining != oldValue.pumpBatteryChargeRemaining && newValue.pumpBatteryChargeRemaining == 0) ||
                (newValue.reservoirUnitsRemaining != oldValue.reservoirUnitsRemaining && newValue.reservoirUnitsRemaining == 0)
            {
                stopInsulinDelivery()
            }
            
            stateObservers.forEach {observer in
                Task { @MainActor in
                    observer.mockPumpManager(self, didUpdate: self.state)
                }
            }

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

    private var deliveryTimer: Timer?
    
    public init() {
        state = MockPumpManagerState(reservoirUnitsRemaining: MockPumpManager.pumpReservoirCapacity)
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.state.finalizeFinishedDoses()
        })
    }

    public init?(rawState: RawStateValue) {
        if let state = (rawState["state"] as? MockPumpManagerState.RawValue).flatMap(MockPumpManagerState.init(rawValue:)) {
            self.state = state
        } else {
            self.state = MockPumpManagerState(reservoirUnitsRemaining: MockPumpManager.pumpReservoirCapacity)
        }
    }

    public var rawState: RawStateValue {
        return ["state": state.rawValue]
    }
    
    public let isOnboarded = true   // No distinction between created and onboarded

    public var inSignalLoss: Bool {
        state.inSignalLoss
    }
    
    public var isInoperable: Bool {
        basalDeliveryState(for: state) == .pumpInoperable
    }
    
    private func logDeviceCommunication(_ message: String, type: DeviceLogEntryType = .send) {
        self.delegate.delegate?.deviceManager(self, logEventForDeviceIdentifier: "MockId", type: type, message: message, completion: nil)
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

    public func ensureCurrentPumpData(completion: ((Date?) -> Void)?) {
        // Change this to artificially increase the delay fetching the current pump data
        let fetchDelay = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(fetchDelay)) {
            
            self.state.finalizeFinishedDoses()

            if !self.state.pumpErrorDetected && !self.state.occlusionDetected && !self.state.isPumpExpired {
                self.lastSync = Date()
            }

            self.storePumpEvents { (error) in
                guard error == nil else {
                    completion?(self.lastSync)
                    return
                }
                
                let totalInsulinUsage = self.state.finalizedDoses.reduce(into: 0 as Double) { total, dose in
                    total += dose.units
                }
                
                self.state.finalizedDoses = []
                self.state.reservoirUnitsRemaining = max(self.state.reservoirUnitsRemaining - totalInsulinUsage, 0)
                
                completion?(self.lastSync)
            }
        }
    }

    private func storePumpEvents(completion: @escaping (_ error: Error?) -> Void) {
        state.finalizeFinishedDoses()
        let pendingPumpEvents = state.pumpEventsToStore
        delegate.notify { (delegate) in
            delegate?.pumpManager(self, hasNewPumpEvents: pendingPumpEvents, lastReconciliation: self.lastSync, replacePendingEvents: true) { error in
                if error == nil {
                    self.state.additionalPumpEvents = []
                }
                completion(error)
            }
        }
    }

    public func enactTempBasal(decisionId: UUID?, unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (PumpManagerError?) -> Void) {
        logDeviceComms(.send, message: "Temp Basal \(unitsPerHour) U/hr Duration:\(duration.hours)")

        if state.tempBasalShouldCrash {
            fatalError("Crashing intentionally on temp basal")
        }
        
        if state.tempBasalEnactmentShouldError || state.pumpBatteryChargeRemaining == 0 {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Temp Basal failed with error \(error)")
            completion(error)
        } else if state.deliveryCommandsShouldTriggerUncertainDelivery {
            state.deliveryIsUncertain = true
            logDeviceComms(.error, message: "Uncertain delivery for temp basal")
            completion(.uncertainDelivery)
        } else if state.occlusionDetected || state.pumpErrorDetected || state.isPumpExpired {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpError)
            logDeviceComms(.error, message: "Temp Basal failed because the pump is in an error state")
            completion(error)
        } else if case .suspended = state.suspendState {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Temp Basal failed because inulin delivery is suspended")
            completion(error)
        } else if state.reservoirUnitsRemaining == 0 {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Temp Basal failed because there is no insulin in the reservoir")
            completion(error)
        } else if state.inSignalLoss {
            let error = PumpManagerError.deviceState(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Temp Basal failed because pump is in signal loss")
            completion(error)
        } else {
            let now = Date()
            if let temp = state.unfinalizedTempBasal, temp.finishTime.compare(now) == .orderedDescending {
                state.unfinalizedTempBasal?.cancel(at: now)
            }
            state.finalizeFinishedDoses()

            logDeviceComms(.receive, message: "Temp Basal succeeded")

            if duration < .ulpOfOne {
                // Cancel temp basal
                storePumpEvents { (error) in
                    completion(nil)
                }
            } else {
                let temp = UnfinalizedDose(tempBasalRate: unitsPerHour, startTime: now, duration: duration, insulinType: state.insulinType, decisionId: decisionId)
                state.unfinalizedTempBasal = temp
                storePumpEvents { (error) in
                    completion(nil)
                }
            }
            logDeviceCommunication("enactTempBasal succeeded", type: .receive)
        }
    }
    
    private func logDeviceComms(_ type: DeviceLogEntryType, message: String) {
        self.delegate.delegate?.deviceManager(self, logEventForDeviceIdentifier: "mockpump", type: type, message: message, completion: nil)
    }

    public func enactBolus(decisionId: UUID?, units: Double, activationType: BolusActivationType, completion: @escaping (PumpManagerError?) -> Void) {

        logDeviceCommunication("enactBolus(\(units), \(activationType))")

        if state.bolusShouldCrash {
            fatalError("Crashing intentionally on bolus")
        }

        if state.bolusEnactmentShouldError || state.pumpBatteryChargeRemaining == 0 {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Bolus failed with error \(error)")
            completion(error)
        } else if state.deliveryCommandsShouldTriggerUncertainDelivery {
            state.deliveryIsUncertain = true
            logDeviceComms(.error, message: "Uncertain delivery for bolus")
            completion(PumpManagerError.uncertainDelivery)
        } else if state.occlusionDetected || state.pumpErrorDetected || state.isPumpExpired {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpError)
            logDeviceComms(.error, message: "Bolus failed because the pump is in an error state")
            completion(error)
        } else if state.reservoirUnitsRemaining == 0 {
            let error = PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended)
            logDeviceComms(.error, message: "Bolus failed because there is no insulin in the reservoir")
            completion(error)
        } else if state.inSignalLoss {
            let error = PumpManagerError.deviceState(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Bolus failed because pump is in signal loss")
            completion(error)
        } else {
            state.finalizeFinishedDoses()

            if let _ = state.unfinalizedBolus {
                logDeviceCommunication("enactBolus failed: bolusInProgress", type: .error)
                completion(PumpManagerError.deviceState(MockPumpManagerError.bolusInProgress))
                return
            }

            if case .suspended = status.basalDeliveryState {
                logDeviceCommunication("enactBolus failed: pumpSuspended", type: .error)
                completion(PumpManagerError.deviceState(MockPumpManagerError.pumpSuspended))
                return
            }
            
            
            let bolus = UnfinalizedDose(bolusAmount: units, startTime: Date(), duration: .minutes(units / type(of: self).deliveryUnitsPerMinute), insulinType: state.insulinType, automatic: activationType.isAutomatic, decisionId: decisionId)
            state.unfinalizedBolus = bolus
            
            logDeviceComms(.receive, message: "Bolus accepted")
            
            storePumpEvents { (error) in
                completion(nil)
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
        } else if state.inSignalLoss {
            let error = PumpManagerError.deviceState(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Cancel failed because pump is in signal loss")
            completion(.failure(error))
        } else {
            state.unfinalizedBolus?.cancel(at: Date())
            let bolusCanceled = state.unfinalizedBolus != nil ? DoseEntry(state.unfinalizedBolus!) : nil
            storePumpEvents { (_) in
                DispatchQueue.main.async {
                    self.state.finalizeFinishedDoses()
                    completion(.success(bolusCanceled))
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
        storePumpEvents { _ in }
        state.suspendState = nil
    }
    
    func issueInsulinSuspensionReminderAlert(reminderDelay: TimeInterval?) {
        guard let reminderDelay = reminderDelay else { return }
        Task {
            await issueAlert(insulinSuspensionReminderAlert(reminderDelay: reminderDelay))
        }
    }
    
    private func retractInsulinSuspensionReminderAlert() {
        Task {
            await retractAlert(identifier: insulinSuspensionReminderAlertIdentifier)
        }
    }

    var insulinSuspensionReminderAlertIdentifier: Alert.Identifier {
        Alert.Identifier(managerIdentifier: pluginIdentifier, alertIdentifier: "insulinSuspensionReminder")
    }

    private func insulinSuspensionReminderAlert(reminderDelay: TimeInterval) -> Alert {
        let identifier = insulinSuspensionReminderAlertIdentifier
        let alertContentForeground = Alert.Content(title: LocalizedString("Delivery Suspension Reminder", comment: "Title of insulin suspension reminder alert"),
                                                   body: LocalizedString("The insulin suspension period has ended. You can resume delivery from the banner on the home screen or from your pump settings screen.", comment: "The body of the insulin suspension reminder alert (in app)"),
                                                   acknowledgeActionButtonLabel: LocalizedString("OK", comment: "Acknowledgement button title for insulin suspension reminder  alert"))
        let alertContentBackground = Alert.Content(title: LocalizedString("Delivery Suspension Reminder", comment: "Title of insulin suspension reminder alert"),
                                                   body: LocalizedString("The insulin suspension period has ended. Return to App and resume.", comment: "The body of the insulin suspension reminder alert (notification)"),
                                                   acknowledgeActionButtonLabel: LocalizedString("OK", comment: "Acknowledgement button title for insulin suspension reminder  alert"))
        return Alert(identifier: identifier,
                     foregroundContent: alertContentForeground,
                     backgroundContent: alertContentBackground,
                     trigger: .delayed(interval: reminderDelay),
                     interruptionLevel: .timeSensitive)
    }
    
    public func suspendDelivery(reminderDelay: TimeInterval, completion: @escaping (Error?) -> Void) {
        suspendDelivery { [weak self] error in
            if error == nil {
                self?.issueInsulinSuspensionReminderAlert(reminderDelay: reminderDelay)
            }
            completion(error)
        }
    }

    public func suspendDelivery(completion: @escaping (Error?) -> Void) {
        logDeviceComms(.send, message: "Suspend")
            
        if self.state.deliverySuspensionShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Suspend failed with error: \(error)")
            completion(error)
        } else if state.inSignalLoss {
            let error = PumpManagerError.deviceState(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Suspend failed because pump is in signal loss")
            completion(error)
        } else {
            let now = Date()
            state.unfinalizedTempBasal?.cancel(at: now)
            state.unfinalizedBolus?.cancel(at: now)


            let suspendDate = Date()
            let suspend = UnfinalizedDose(suspendStartTime: suspendDate, automatic: false)
            self.state.finalizedDoses.append(suspend)
            self.state.suspendState = .suspended(suspendDate)
            logDeviceComms(.receive, message: "Suspend accepted")

            storePumpEvents { (error) in
                completion(error)
            }
            logDeviceCommunication("suspendDelivery succeeded", type: .receive)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completion(nil)
            }
        }
    }

    public func resumeDelivery(completion: @escaping (Error?) -> Void) {
        logDeviceComms(.send, message: "Resume")

        if self.state.deliveryResumptionShouldError {
            let error = PumpManagerError.communication(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Resume failed with error: \(error)")
            completion(error)
        } else if state.inSignalLoss {
            let error = PumpManagerError.deviceState(MockPumpManagerError.communicationFailure)
            logDeviceComms(.error, message: "Resume failed because pump is in signal loss")
            completion(error)
        } else {
            let resumeDate = Date()
            let resume = UnfinalizedDose(resumeStartTime: resumeDate, insulinType: state.insulinType, automatic: false)
            state.finalizedDoses.append(resume)
            state.suspendState = .resumed(resumeDate)
            logDeviceCommunication("resumeDelivery succeeded", type: .receive)
            retractInsulinSuspensionReminderAlert()
            storePumpEvents { (error) in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    completion(error)
                }
            }
        }
    }
    
    public func trigger(action: DeviceAction) {}
    
    public var pumpTimeZone: TimeZone {
        state.timeZone
    }
    
    public func setPumpTime(_ newPumpTime: Date = Date(), using timeZone: TimeZone, completion: @escaping (Error?) -> Void) {
        logDeviceCommunication("set pump time success", type: .receive)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.recordPumpTime(newPumpTime, in: timeZone)
            completion(nil)
        }
    }
        
    private func recordPumpTime(_ pumpTime: Date, in timeZone: TimeZone) {
        state.timeZone = timeZone
    }

    public func injectPumpEvents(_ pumpEvents: [NewPumpEvent]) {
        // directly report these pump events
        delegate.notify { delegate in
            delegate?.pumpManager(self, hasNewPumpEvents: pumpEvents, lastReconciliation: Date(), replacePendingEvents: true) { _ in }
        }
    }
    
    public func setMaximumTempBasalRate(_ rate: Double) { }

    public func syncBasalRateSchedule(items scheduleItems: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        state.basalRateSchedule = BasalRateSchedule(dailyItems: scheduleItems, timeZone: self.status.timeZone)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            completion(.success(BasalRateSchedule(dailyItems: scheduleItems, timeZone: self.status.timeZone)!))
        }
    }

    public func syncDeliveryLimits(limits deliveryLimits: DeliveryLimits, completion: @escaping (Result<DeliveryLimits, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            completion(.success(deliveryLimits))
        }
    }
}

extension MockPumpManager {
    public func acceptDefaultsAndSkipOnboarding() {
        // TODO: Unimplemented as it's not needed for HF. Ticket to complete below.
        // https://tidepool.atlassian.net/browse/LOOP-4599
    }
}

// MARK: - AlertResponder implementation
extension MockPumpManager: AlertIssuer {
    public func issueAlert(_ alert: Alert) {
        logDeviceComms(.delegate, message: "issuing \(alert.identifier) \(alert.backgroundContent.title) with trigger \(alert.trigger)")
        delegate.notify { delegate in
            guard let delegate else { return }
            Task {
                await delegate.issueAlert(alert)
            }
        }
    }
    
    public func retractAlert(identifier: Alert.Identifier) {
        logDeviceComms(.delegate, message: "retracting \(identifier)")
        delegate.notify { delegate in
            guard let delegate else { return }
            Task {
                await delegate.retractAlert(identifier: identifier)
            }
        }
    }
    
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) async throws {
        logDeviceComms(.delegate, message: "acknowledging \(alertIdentifier)")

        if alertIdentifier == insulinSuspensionReminderAlertIdentifier.alertIdentifier {
            if case .suspended = state.suspendState {
                // subsequent reminder are delayed 15 mins
                issueInsulinSuspensionReminderAlert(reminderDelay: .minutes(15))
            }
            return
        }
        
    }

    public func handleAlertAction(actionIdentifier: String, from alert: Alert) async throws {
    }
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
