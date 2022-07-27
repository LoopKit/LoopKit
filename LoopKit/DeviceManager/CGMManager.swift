//
//  CGMManager.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit

/// Describes the result of CGM manager operations to fetch and report sensor readings.
///
/// - noData: No new data was available or retrieved
/// - unreliableData: New glucose data was received, but is not reliable enough to use for therapy
/// - newData: New glucose data was received and stored
/// - error: An error occurred while receiving or store data
public enum CGMReadingResult {
    case noData
    case unreliableData
    case newData([NewGlucoseSample])
    case error(Error)
}

public struct CGMManagerStatus: Equatable {
    // Return false if no sensor active, or in a state where no future data is expected without user intervention
    public var hasValidSensorSession: Bool

    public var lastCommunicationDate: Date?

    public var device: HKDevice?
    
    public init(hasValidSensorSession: Bool, lastCommunicationDate: Date? = nil, device: HKDevice?) {
        self.hasValidSensorSession = hasValidSensorSession
        self.lastCommunicationDate = lastCommunicationDate
        self.device = device
    }
}

extension CGMManagerStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hasValidSensorSession = try container.decode(Bool.self, forKey: .hasValidSensorSession)
        self.lastCommunicationDate = try container.decodeIfPresent(Date.self, forKey: .lastCommunicationDate)
        self.device = try container.decodeIfPresent(CodableDevice.self, forKey: .device)?.device
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasValidSensorSession, forKey: .hasValidSensorSession)
        try container.encodeIfPresent(lastCommunicationDate, forKey: .lastCommunicationDate)
        try container.encodeIfPresent(device.map { CodableDevice($0) }, forKey: .device)
    }

    private enum CodingKeys: String, CodingKey {
        case hasValidSensorSession
        case lastCommunicationDate
        case device
    }
}

public protocol CGMManagerStatusObserver: AnyObject {
    /// Notifies observers of changes in CGMManagerStatus
    ///
    /// - Parameter manager: The manager instance
    /// - Parameter status: The new, updated status. Status includes properties associated with the manager, transmitter, or sensor,
    ///                     that are not part of an individual sensor reading.
    func cgmManager(_ manager: CGMManager, didUpdate status: CGMManagerStatus)
}

public protocol CGMManagerDelegate: DeviceManagerDelegate, CGMManagerStatusObserver {
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
    func cgmManager(_ manager: CGMManager, hasNew readingResult: CGMReadingResult) -> Void

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
    
    /// The length of time to delay until storing samples into HealthKit.  Return 0 for no delay.
    static var healthKitStorageDelay: TimeInterval { get }

    var shouldSyncToRemoteService: Bool { get }

    var glucoseDisplay: GlucoseDisplayable? { get }

    /// The current status of the cgm manager
    var cgmManagerStatus: CGMManagerStatus { get }

    /// The queue on which CGMManagerDelegate methods are called
    /// Setting to nil resets to a default provided by the manager
    var delegateQueue: DispatchQueue! { get set }


    /// Implementations of this function must call the `completion` block, with the appropriate `CGMReadingResult`
    /// according to the current available data.
    /// - If there is new unreliable data, return `.unreliableData`
    /// - If there is no new data and the current data is unreliable, return `.unreliableData`
    /// - If there is new reliable data, return `.newData` with the data samples
    /// - If there is no new data and the current data is reliable, return `.noData`
    /// - If there is an error, return `.error` with the appropriate error.
    ///
    /// - Parameters:
    ///   - completion: A closure called when operation has completed
    func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) -> Void

    /// Adds an observer of changes in CGMManagerStatus
    ///
    /// Observers are held by weak reference.
    ///
    /// - Parameters:
    ///   - observer: The observing object
    ///   - queue: The queue on which the observer methods should be called
    func addStatusObserver(_ observer: CGMManagerStatusObserver, queue: DispatchQueue)

    /// Removes an observer of changes in CGMManagerStatus
    ///
    /// Since observers are held weakly, calling this method is not required when the observer is deallocated
    ///
    /// - Parameter observer: The observing object
    func removeStatusObserver(_ observer: CGMManagerStatusObserver)

    /// Requests that the manager completes its deletion process
    ///
    /// - Parameter completion: Action to take after the CGM manager is deleted
    func delete(completion: @escaping () -> Void)
}


public extension CGMManager {
    var appURL: URL? {
        return nil
    }
    
    /// Default is no delay to store samples in HealthKit
    static var healthKitStorageDelay: TimeInterval { 0 }

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
    
    func addStatusObserver(_ observer: CGMManagerStatusObserver, queue: DispatchQueue) {
        // optional since a CGM manager may not support status observers
    }

    func removeStatusObserver(_ observer: CGMManagerStatusObserver) {
        // optional since a CGM manager may not support status observers
    }

    /// Override this default behaviour if the CGM Manager needs to complete tasks before being deleted
    func delete(completion: @escaping () -> Void) {
        notifyDelegateOfDeletion(completion: completion)
    }
}
