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

public protocol PumpManagerStatusObserver: AnyObject {
    func pumpManager(_ pumpManager: PumpManager, didUpdate status: PumpManagerStatus, oldStatus: PumpManagerStatus)
}

public enum BolusActivationType: String, Codable {
    case manualNoRecommendation
    case manualRecommendationAccepted
    case manualRecommendationChanged
    case automatic

    public var isAutomatic: Bool {
        self == .automatic
    }

    static public func activationTypeFor(recommendedAmount: Double?, bolusAmount: Double) -> BolusActivationType {
        guard let recommendedAmount = recommendedAmount else { return .manualNoRecommendation }
        return recommendedAmount =~ bolusAmount ? .manualRecommendationAccepted : .manualRecommendationChanged
    }
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
    func pumpManager(_ pumpManager: PumpManager, hasNewPumpEvents events: [NewPumpEvent], lastReconciliation: Date?, completion: @escaping (_ error: Error?) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: Result<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool), Error>) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval)

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager)

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date

    /// Indicates the system time offset from a trusted time source. If the return value is added to the system time, the result is the trusted time source value. If the trusted time source is earlier than the system time, the return value is negative.
    var detectedSystemTimeOffset: TimeInterval { get }
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
    func enactBolus(units: Double, activationType: BolusActivationType, completion: @escaping (_ error: PumpManagerError?) -> Void)

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
    func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (_ error: PumpManagerError?) -> Void)

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
}


public extension PumpManager {
    func roundToSupportedBasalRate(unitsPerHour: Double) -> Double {
        return supportedBasalRates.filter({$0 <= unitsPerHour}).max() ?? 0
    }

    func roundToSupportedBolusVolume(units: Double) -> Double {
        return supportedBolusVolumes.filter({$0 <= units}).max() ?? 0
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
