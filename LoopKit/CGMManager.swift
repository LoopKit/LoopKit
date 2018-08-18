//
//  CGMManager.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Describes the result of a CGM manager operation
///
/// - noData: No new data was available or retrieved
/// - newData: New glucose data was received and stored
/// - error: An error occurred while receiving or store data
public enum CGMResult {
    case noData
    case newData([NewGlucoseSample])
    case error(Error)
}


public protocol CGMManagerDelegate: class {
    /// Asks the delegate for a date with which to filter incoming glucose data
    ///
    /// - Parameter manager: The manager instance
    /// - Returns: The date data occuring on or after which should be kept
    func startDateToFilterNewData(for manager: CGMManager) -> Date?

    /// Informs the delegate that the device has updated with a new result
    ///
    /// - Parameters:
    ///   - manager: The manager instance
    ///   - result: The result of the update
    func cgmManager(_ manager: CGMManager, didUpdateWith result: CGMResult) -> Void
}


public protocol CGMManager: CustomDebugStringConvertible {
    var cgmManagerDelegate: CGMManagerDelegate? { get set }

    /// Whether the device is capable of waking the app
    var providesBLEHeartbeat: Bool { get }

    /// The length of time to keep samples in HealthKit before removal. Return nil to never remove samples.
    var managedDataInterval: TimeInterval? { get }

    var shouldSyncToRemoteService: Bool { get }

    var sensorState: SensorDisplayable? { get }

    /// The representation of the device for use in HealthKit
    var device: HKDevice? { get }

    /// Performs a manual fetch of glucose data from the device, if necessary
    ///
    /// - Parameters:
    ///   - completion: A closure called when operation has completed
    func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) -> Void
}
