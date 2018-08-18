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


public protocol PumpManagerDelegate: class {
    func pumpManagerBLEHeartbeatDidFire(_ pumpManager: PumpManager)

    func pumpManagerShouldProvideBLEHeartbeat(_ pumpManager: PumpManager) -> Bool

    // Strictly for Nightscout uploading
    // Can this be rolled into another update message?
    func pumpManager(_ pumpManager: PumpManager, didUpdateStatus status: PumpManagerStatus)

    /// Basically, the pumpID is now gone, we have nothing left to do
    /// Could we make the Pump ID required but keep the interface generic?
    func pumpManagerWillDeactivate(_ pumpManager: PumpManager)

    /// Triggered when pump model changes. With a more formalized setup flow (which requires a successful model fetch),
    /// this delegate method could go away.
    func pumpManager(_ pumpManager: PumpManager, didUpdatePumpRecordsBasalProfileStartEvents pumpRecordsBasalProfileStartEvents: Bool)

    /// Reports an error that should be surfaced to the user
    func pumpManager(_ pumpManager: PumpManager, didError error: PumpManagerError)

    func pumpManager(_ pumpManager: PumpManager, didReadPumpEvents events: [NewPumpEvent], completion: @escaping (_ error: Error?) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didReadReservoirValue units: Double, at date: Date, completion: @escaping (_ result: PumpManagerResult<(newValue: ReservoirValue, lastValue: ReservoirValue?, areStoredValuesContinuous: Bool)>) -> Void)

    func pumpManager(_ pumpManager: PumpManager, didAdjustPumpClockBy adjustment: TimeInterval)

    func pumpManagerDidUpdatePumpBatteryChargeRemaining(_ pumpManager: PumpManager, oldValue: Double?)

    func pumpManagerDidUpdateState(_ pumpManager: PumpManager)

    func pumpManagerRecommendsLoop(_ pumpManager: PumpManager)

    func startDateToFilterNewPumpEvents(for manager: PumpManager) -> Date

    func startDateToFilterNewReservoirEvents(for manager: PumpManager) -> Date
}


public protocol PumpManager: class, CustomDebugStringConvertible {
    typealias RawStateValue = [String: Any]

    /// The identifier of the manager. This should be unique
    static var managerIdentifier: String { get }

    /// Initializes the pump manager with its previously-saved state
    ///
    /// Return nil if the saved state is invalid to prevent restoration
    ///
    /// - Parameter rawState: The last state
    init?(rawState: RawStateValue)

    /// The current, serializable state of the manager
    var rawState: RawStateValue { get }

    var pumpManagerDelegate: PumpManagerDelegate? { get set }

    var localizedTitle: String { get }

    // Pump info
    var pumpBatteryChargeRemaining: Double? { get }

    var pumpRecordsBasalProfileStartEvents: Bool { get }

    var pumpReservoirCapacity: Double { get }

    /// Only used by settings
    var pumpTimeZone: TimeZone { get }

    /// If the pump data (reservoir/events) is out of date, it will be fetched, and if successful, trigger a loop
    func assertCurrentPumpData()

    /// Send a bolus command and handle the result
    ///
    /// - Parameters:
    ///   - units: The number of units to deliver
    ///   - startDate: The date the bolus command was originally set
    ///   - willRequest: A closure called just before the pump command is sent, if all preconditions are met
    ///   - units: The number of units requested
    ///   - date: The date the request was made
    ///   - completion: A closure called after the command is complete
    ///   - error: An error describing why the command failed
    func enactBolus(units: Double, at startDate: Date, willRequest: @escaping (_ units: Double, _ date: Date) -> Void, completion: @escaping (_ error: Error?) -> Void)

    func enactTempBasal(unitsPerHour: Double, for duration: TimeInterval, completion: @escaping (_ result: PumpManagerResult<DoseEntry>) -> Void)

    func updateBLEHeartbeatPreference()
}
