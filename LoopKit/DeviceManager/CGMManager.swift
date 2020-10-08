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


public protocol CGMManagerDelegate: DeviceManagerDelegate {
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

    /// Informs the delegate that the manager is deactivating and should be deleted
    ///
    /// - Parameter manager: The manager instance
    func cgmManagerWantsDeletion(_ manager: CGMManager)

    /// Informs the delegate that the manager has updated its state and should be persisted.
    ///
    /// - Parameter manager: The manager instance
    func cgmManagerDidUpdateState(_ manager: CGMManager)
    
    /// Asks the delegate for credential store prefix to avoid namespace conflicts
    ///
    /// - Parameter manager: The manager instance
    /// - Returns: The unique prefix for the credential store
    func credentialStoragePrefix(for manager: CGMManager) -> String
}


public protocol CGMManager: DeviceManager {
    var cgmManagerDelegate: CGMManagerDelegate? { get set }

    var appURL: URL? { get }

    /// Whether the device is capable of waking the app
    var providesBLEHeartbeat: Bool { get }

    /// The length of time to keep samples in HealthKit before removal. Return nil to never remove samples.
    var managedDataInterval: TimeInterval? { get }

    var shouldSyncToRemoteService: Bool { get }

    var glucoseDisplay: GlucoseDisplayable? { get }

    /// The representation of the device for use in HealthKit
    var device: HKDevice? { get }

    /// Performs a manual fetch of glucose data from the device, if necessary
    ///
    /// - Parameters:
    ///   - completion: A closure called when operation has completed
    func fetchNewDataIfNeeded(_ completion: @escaping (CGMResult) -> Void) -> Void
}


public extension CGMManager {
    var appURL: URL? {
        return nil
    }

    /// Convenience wrapper for notifying the delegate of deletion on the delegate queue
    ///
    /// - Parameters:
    ///   - completion: A closure called from the delegate queue after the delegate is called
    func notifyDelegateOfDeletion(completion: @escaping () -> Void) {
        delegateQueue.async {
            self.cgmManagerDelegate?.cgmManagerWantsDeletion(self)
            completion()
        }
    }
}
