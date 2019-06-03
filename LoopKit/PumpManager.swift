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
    case failure(Error)
}

public protocol PumpManagerStatusObserver: class {
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

    /// Triggered when pump model changes. With a more formalized setup flow (which requires a successful model fetch),
    /// this delegate method could go away.
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool)

    /// Reports an error that should be surfaced to the user
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError)

    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (_ error: Error?) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval)

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager)

    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager)

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date
}


public protocol PumpManager: DeviceManager {
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
    
    /// Fetch the pump data (reservoir/events) if it is out of date.
    /// After a successful fetch, the PumpManager should trigger a loop by calling the delegate method `pumpManagerRecommendsLoop(_:)`
    func assertCurrentPumpData()

    /// Loop calls this method when the current environment requires the pump to provide its own periodic
    /// scheduling via BLE.
    /// The manager may choose to still enable its own heartbeat even if `mustProvideBLEHeartbeat` is false
    func setMustProvideBLEHeartbeat(_ mustProvideBLEHeartbeat: Bool)

    /// Returns a dose estimator for the current bolus, if one is in progress
    func createBolusProgressReporter(reportingOn dispatchQueue: DispatchQueue) -> DoseProgressReporter?

    /// Send a bolus command and handle the result
    ///
    /// - Parameters:
    ///   - units: The number of units to deliver
    ///   - startDate: The date the bolus command was originally set
    ///   - willRequest: A closure called just before the pump command is sent, if all preconditions are met
    ///   - completion: A closure called after the command is complete
    ///   - result: A DoseEntry or an error describing why the command failed
    func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (_ dose: DoseEntry) -> Void, completion: @escaping (_ result: PumpManagerResult<DoseEntry>) -> Void)

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
    ///   - duration: The duration of the temporary basal rate.
    ///   - completion: A closure called after the command is complete
    ///   - result: A DoseEntry or an error describing why the command failed
    func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (_ result: PumpManagerResult<DoseEntry>) -> Void)

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
