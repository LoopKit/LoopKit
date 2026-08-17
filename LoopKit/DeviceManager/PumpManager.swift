//
//  PumpManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum PumpManagerResult<T> {
    case success(T)
    case failure(PumpManagerError)
}

public enum AutomatedTreatmentState: Equatable {
    case neutralNoOverride
    case neutralOverride
    case increasedInsulin
    case decreasedInsulin
    case minimumDelivery
}

/// Describes a request that the pump provide its own periodic BLE heartbeat (used when the CGM cannot
/// wake the app, e.g. a network/remote CGM). Rather than a bare "provide a heartbeat" flag, it tells the
/// pump *when* the last CGM reading landed and how often readings are expected, so the pump can schedule
/// its next heartbeat to arrive just *after* the next reading is due — see `setBLEHeartbeatRequest(_:)`.
public struct PumpHeartbeatRequest: Equatable {
    /// The date of the most recent CGM reading, if any. `nil` when no reading has been received yet.
    public let lastCGMReadingDate: Date?

    /// The expected interval between CGM readings (e.g. 5 minutes for most CGMs).
    public let expectedCGMReadingInterval: TimeInterval

    public init(lastCGMReadingDate: Date?, expectedCGMReadingInterval: TimeInterval) {
        self.lastCGMReadingDate = lastCGMReadingDate
        self.expectedCGMReadingInterval = expectedCGMReadingInterval
    }
}

public protocol PumpManagerStatusObserver: AnyObject {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus)
}

public protocol PumpManagerDelegate: DeviceManagerDelegate, PumpManagerStatusObserver {
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager)

    /// Queries the delegate as to whether Loop requires the pump to provide its own periodic scheduling
    /// via BLE.
    /// This is the companion to `PumpManager.setMustProvideBLEHeartbeat(_:)`
    func pumpManagerMustProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool

    /// Informs the delegate that the manager is deactivating and should be deleted
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager)

    /// Informs the delegate that the hardware this PumpManager has been reporting for has been replaced.
    func pumpManagerPumpWasReplaced(_ pumpManager: PumpManager)

    /// Triggered when pump model changes. With a more formalized setup flow (which requires a successful model fetch),
    /// this delegate method could go away.
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool)

    /// Reports an error that should be surfaced to the user
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError)

    /// This should be called any time the PumpManager synchronizes with the pump, even if there are no new doses in the log, as changes to lastReconciliation
    /// indicate we can trust insulin delivery status up until that point, even if there are no new doses.
    /// For pumps whose only source of dosing adjustments is Loop, lastReconciliation should be reflective of the last time we received telemetry from the pump.
    /// For pumps with a user interface and dosing history capabilities, lastReconciliation should be reflective of the last time we reconciled fully with pump history, and know
    /// that we have accounted for any external doses. It is possible for the pump to report reservoir data beyond the date of lastReconciliation, and Loop can use it for
    /// calculating IOB.
    func pumpManager(_ pumpManager: PumpManager, hasNewPumpEvents events: [NewPumpEvent], lastReconciliation: Date?, replacePendingEvents: Bool, completion: @escaping (_ error: Error?) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: Result<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool), Error>) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval)

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager)
    
    func pumpManager(_ pumpManager: PumpManager, didRequestBasalRateScheduleChange basalRateSchedule: BasalRateSchedule, completion: @escaping (Error?) -> Void)

    @MainActor
    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date

    /// Indicates the system time offset from a trusted time source. If the return value is added to the system time, the result is the trusted time source value. If the trusted time source is earlier than the system time, the return value is negative.
    var detectedSystemTimeOffset: TimeInterval { get }

    /// Indicates if automatic dosing has been enabled
    @MainActor
    var automaticDosingEnabled: Bool { get }

    @MainActor
    var automatedTreatmentState: AutomatedTreatmentState? { get }
}


public protocol PumpManager: DeviceManager {
    /// The maximum number of scheduled basal rates in a single day supported by the pump. Used during onboarding by therapy settings.
    static var onboardingMaximumBasalScheduleEntryCount: Int { get }

    /// All user-selectable basal rates, in Units per Hour. Must be non-empty. Used during onboarding by therapy settings.
    static var onboardingSupportedBasalRates: [Double] { get }

    /// All user-selectable bolus volumes, in Units. Must be non-empty. Used during onboarding by therapy settings.
    static var onboardingSupportedBolusVolumes: [Double] { get }

    /// All user-selectable maximum bolus volumes, in Units. Must be non-empty. Used during onboarding by therapy settings.
    static var onboardingSupportedMaximumBolusVolumes: [Double] { get }

    /// The queue on which PumpManagerDelegate methods are called
    /// Setting to nil resets to a default provided by the manager
    var delegateQueue: DispatchQueue! { get set }

    /// Rounds a basal rate in U/hr to a rate supported by this pump.
    ///
    /// - Parameters:
    ///   - unitsPerHour: A desired rate of delivery in Units per Hour
    /// - Returns: The rounded rate of delivery in Units per Hour. The rate returned should not be larger than the passed in rate.
    func roundToSupportedBasalRate(unitsPerHour: Double) -> Double

    /// Rounds a bolus volume in Units to a volume supported by this pump.
    ///
    /// - Parameters:
    ///   - units: A desired volume of delivery in Units
    /// - Returns: The rounded bolus volume in Units. The volume returned should not be larger than the passed in rate.
    func roundToSupportedBolusVolume(units: Double) -> Double

    /// All user-selectable basal rates, in Units per Hour. Must be non-empty.
    var supportedBasalRates: [Double] { get }

    /// All user-selectable bolus volumes, in Units. Must be non-empty.
    var supportedBolusVolumes: [Double] { get }

    /// All user-selectable bolus volumes for setting the maximum allowed bolus, in Units. Must be non-empty.
    var supportedMaximumBolusVolumes: [Double] { get }

    /// The maximum number of scheduled basal rates in a single day supported by the pump
    var maximumBasalScheduleEntryCount: Int { get }

    /// The basal schedule duration increment, beginning at midnight, supported by the pump
    var minimumBasalScheduleEntryDuration: TimeInterval { get }

    /// The primary client receiving notifications about the pump lifecycle
    /// All delegate methods are called on `delegateQueue`
    var pumpManagerDelegate: PumpManagerDelegate? { get set }
    
    /// Whether the PumpManager provides DoseEntry values for scheduled basal delivery. If false, Loop will use the basal schedule to infer normal basal delivery during times not overridden by:
    ///  - Temporary basal delivery
    ///  - Suspend/Resume pairs
    ///  - Rewind/Prime pairs
    var pumpRecordsBasalProfileStartEvents: Bool { get }

    /// The maximum reservoir volume of the pump
    var pumpReservoirCapacity: Double { get }

    /// The time of the last sync with the pump's event history, or reservoir,  or last status check if pump does not provide history.
    var lastSync: Date? { get }
    
    /// The most-recent status
    var status: PumpManagerStatus { get }

    /// Adds an observer of changes in PumpManagerStatus
    ///
    /// Observers are held by weak reference.
    ///
    /// - Parameters:
    ///   - observer: The observing object
    ///   - queue: The queue on which the observer methods should be called
    func addStatusObserver(_ observer: PumpManagerStatusObserver, queue: DispatchQueue)
    
    /// Removes an observer of changes in PumpManagerStatus
    ///
    /// Since observers are held weakly, calling this method is not required when the observer is deallocated
    ///
    /// - Parameter observer: The observing object
    func removeStatusObserver(_ observer: PumpManagerStatusObserver)
    
    /// Ensure that the pump's data (reservoir/events) is up to date.  If not, fetch it.
    /// The PumpManager should call the completion block with the date of last sync with the pump, nil if no sync has occurred
    func ensureCurrentPumpData(completion: ((_ lastSync: Date?) -> Void)?)
    
    /// Loop calls this method when the current environment requires the pump to provide its own periodic
    /// scheduling via BLE.
    /// The manager may choose to still enable its own heartbeat even if `mustProvideBLEHeartbeat` is false
    func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool)

    /// Loop calls this to tell the pump whether it must provide its own periodic BLE heartbeat, and — when
    /// it must — when the last CGM reading landed and how often readings are expected. `request == nil`
    /// means no pump heartbeat is required (the CGM wakes the app itself). When non-nil, the pump should
    /// schedule its next heartbeat to fire no earlier than
    /// `lastCGMReadingDate + expectedCGMReadingInterval` (plus a small buffer, since the heartbeat usually
    /// drives fetching a remote CGM value that then needs time to be stored). The manager may still run its
    /// own heartbeat when `request` is nil.
    ///
    /// A default implementation bridges to `setMustProvideBLEHeartbeat(_:)` for managers that don't need the
    /// timing detail, so existing PumpManagers need not implement this.
    func setBLEHeartbeatRequest(_ request: PumpHeartbeatRequest?)

    /// Returns a dose estimator for the current bolus, if one is in progress
    func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter?

    /// Returns the estimated time for the bolus amount to be delivered
    func estimatedDuration(toBolus units: Double) -> TimeInterval
    
    /// Send a bolus command and handle the result
    ///
    /// - Parameters:
    ///   - units: The number of units to deliver
    ///   - automatic: Whether the dose was triggered automatically as opposed to commanded by user
    ///   - completion: A closure called after the command is complete
    ///   - error: An optional error describing why the command failed
    func enactBolus(decisionId: UUID?, units: Double, activationType: BolusActivationType, completion: @escaping (_ error: PumpManagerError?) -> Void)

    /// Cancels the current, in progress, bolus.
    ///
    /// - Parameters:
    ///   - completion: A closure called after the command is complete
    ///   - result: A DoseEntry containing the actual delivery amount of the canceled bolus, nil if canceled bolus information is not available, or an error describing why the command failed.
    func cancelBolus(completion: @escaping (_ result: PumpManagerResult<DoseEntry?>) -> Void)

    /// Send a temporary basal rate command and handle the result
    ///
    /// - Parameters:
    ///   - unitsPerHour: The temporary basal rate to set
    ///   - duration: The duration of the temporary basal rate.  If you pass in a duration of 0, that cancels any currently running Temp Basal
    ///   - completion: A closure called after the command is complete
    ///   - error: An optional error describing why the command failed
    func enactTempBasal(decisionId: UUID?, unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (_ error: PumpManagerError?) -> Void)

    /// Send a command to the pump to suspend delivery
    ///
    /// - Parameters:
    ///   - completion: A closure called after the command is complete
    ///   - error: An error describing why the command failed
    func suspendDelivery(completion: @escaping (_ error: Error?) -> Void)

    /// Send a command to the pump to resume delivery
    ///
    /// - Parameters:
    ///   - completion: A closure called after the command is complete
    ///   - error: An error describing why the command failed
    func resumeDelivery(completion: @escaping (_ error: Error?) -> Void)
    
    /// Sync the schedule of basal rates to the pump, annotating the result with the proper time zone.
    ///
    /// - Precondition:
    ///   - `scheduleItems` must not be empty.
    ///
    /// - Parameters:
    ///   - scheduleItems: The items comprising the basal rate schedule
    ///   - completion: A closure called after the command is complete
    ///   - result: A BasalRateSchedule or an error describing why the command failed
    func syncBasalRateSchedule(items scheduleItems: [RepeatingScheduleValue<Double>], completion: @escaping (_ result: Result<BasalRateSchedule, Error>) -> Void)

    /// Sync the delivery limits for basal rate and bolus. If the pump does not support setting max bolus or max basal rates, the completion should be called with success including the provided delivery limits.
    ///
    /// - Parameters:
    ///   - deliveryLimits: The delivery limits
    ///   - completion: A closure called after the command is complete
    ///   - result: The delivery limits set or an error describing why the command failed
    func syncDeliveryLimits(limits deliveryLimits: DeliveryLimits, completion: @escaping (_ result: Result<DeliveryLimits, Error>) -> Void)
    
    ///
    /// Warn the pump manager that it will be deactivated
    ///
    /// - Parameters:
    ///   - completion: A closure called after preparations are complete
    func prepareForDeactivation(_ completion: @escaping (Error?) -> Void)
}


public extension PumpManager {
    /// Default bridge for managers that only need the boolean "must provide a heartbeat" signal.
    func setBLEHeartbeatRequest(_ request: PumpHeartbeatRequest?) {
        setMustProvideBLEHeartbeat(request != nil)
    }

    func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
        return supportedBasalRates.filter({$0 <= unitsPerHour}).max() ?? 0
    }

    func roundToSupportedBolusVolume(units: Double) -> Double {
        return supportedBolusVolumes.filter({$0 <= units}).max() ?? 0
    }
    
    func prepareForDeactivation(_ completion: @escaping (Error?) -> Void) {
        notifyDelegateOfDeactivation() { completion(nil) }
    }

    /// Convenience wrapper for notifying the delegate of deactivation on the delegate queue
    ///
    /// - Parameters:
    ///   - completion: A closure called from the delegate queue after the delegate is called
    func notifyDelegateOfDeactivation(completion: @escaping () -> Void) {
        delegateQueue.async {
            self.pumpManagerDelegate?.pumpManagerWillDeactivate(self)
            completion()
        }
    }
}

public extension PumpManager {

    func enactTempBasal(decisionId: UUID?, unitsPerHour: Double, for duration: TimeInterval) async throws
    {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            enactTempBasal(decisionId: decisionId, unitsPerHour: unitsPerHour, for: duration, completion: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func enactBolus(decisionId: UUID?, units: Double, activationType: BolusActivationType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            enactBolus(decisionId: decisionId, units: units, activationType: activationType, completion: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func cancelBolus() async throws -> DoseEntry? {
        try await withCheckedThrowingContinuation { continuation in
            cancelBolus() { result in
                switch result {
                case .success(let dose):
                    continuation.resume(returning: dose)
                case .failure(let pumpManagerError):
                    continuation.resume(throwing: pumpManagerError)
                }
            }
        }
    }


    @discardableResult
    func ensureCurrentPumpData() async -> Date? {
        await withCheckedContinuation { (continuation) in
            ensureCurrentPumpData { lastSync in
                continuation.resume(returning: lastSync)
            }
        }
    }

    func syncDeliveryLimits(limits deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits
    {
        return try await withCheckedThrowingContinuation { (continuation) in
            syncDeliveryLimits(limits: deliveryLimits) { result in
                continuation.resume(with: result)
            }
        }
    }
}


// MARK: - PumpConnectionLendable (optional capability)  // PODLOAN

/// An OPTIONAL capability for pump managers whose device connection can be
/// deliberately released — loaned to another controller (e.g. an Apple Watch
/// commanding the pump directly) — and later reclaimed.
///
/// Motivation: some pumps (Omnipod DASH) hold a single BLE connection and give
/// it to whichever credentialed controller connects last. A pump manager that
/// maintains a standing auto-connect therefore reclaims the device within
/// seconds of any radio availability, making a deliberate second-controller
/// session impossible without disabling the phone's radio entirely. This
/// capability lets the app ask the manager to stand down on purpose.
///
/// Managers that cannot support a deliberate release simply do not conform,
/// and no behavior changes. Callers discover the capability by conditional
/// cast, as with other optional capabilities.
public protocol PumpConnectionLendable: AnyObject {
    /// True while the connection is deliberately released (a loan is active).
    /// Implementations should persist this so an app relaunch mid-loan does not
    /// silently re-arm the connection and steal the device back.
    var isConnectionReleased: Bool { get }

    /// Stop bidding for the device's connection so another controller can hold
    /// it uncontested. Must leave device state, pairing and keys intact.
    func releaseConnection()

    /// Resume bidding for the device's connection after a loan ends.
    func reclaimConnection()

    /// The device's cumulative-delivered odometer as last reported, if the pump
    /// keeps one — an AUDIT input for post-loan reconciliation, never a record
    /// source. Default: nil (no odometer).
    var lentDeviceInsulinDelivered: Double? { get }

    /// Force a real status round-trip (bypassing freshness optimizations) so the
    /// odometer is current before an audit read. Completion: success.
    /// Default: completes false (no forced read available).
    func refreshLentDeviceStatus(completion: @escaping (Bool) -> Void)

    /// True once a reclaimed connection is TRULY re-established (the link is up and the
    /// device is reachable). `reclaimConnection()` only re-arms the bid; the actual reconnect
    /// can land seconds-to-minutes later, so UI that must wait for the device (e.g. a
    /// "reclaiming…" indicator) keys on this rather than on the loan flag clearing. Default:
    /// true — a manager that can't report readiness never appears stuck "reconnecting".
    var isConnectionReady: Bool { get }

    /// Escalate a reclaim whose link has not come back, from whatever gentle reconnect the
    /// manager uses by default to its most aggressive reacquisition.
    ///
    /// `reclaimConnection()` only re-arms the bid, and for a device idle a while that bid is
    /// probabilistic — it depends on happening to hear the device announce itself. A manager that
    /// can instead go LOOKING (scanning for the device by address) should do so here. Called at
    /// most once per reclaim and only after the link has failed to come up within a grace period,
    /// so this is a recovery path, not the normal one.
    ///
    /// Idempotent, and safe to call when nothing needs escalating.
    ///
    /// RETURNS a short description of what it actually did, for the CALLER to log. The manager's
    /// own logging goes to os_log, which is invisible in the file logs field analysis reads — an
    /// escalation that silently no-ops (no device address, wrong state) is otherwise
    /// indistinguishable from one that ran and found nothing, and those need opposite fixes.
    /// nil means "nothing to escalate".
    ///
    /// Default: nil — a manager with a single reconnect strategy has nothing to escalate to.
    @discardableResult
    func escalateConnectionReclaim() -> String?
}

extension PumpConnectionLendable {
    public var lentDeviceInsulinDelivered: Double? { return nil }
    public func refreshLentDeviceStatus(completion: @escaping (Bool) -> Void) { completion(false) }
    public var isConnectionReady: Bool { return true }
    public func escalateConnectionReclaim() -> String? { return nil }
}
