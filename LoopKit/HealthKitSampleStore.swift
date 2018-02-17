//
//  HealthKitSampleStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import os.log


extension Notification.Name {
    public static let StoreAuthorizationStatusDidChange = Notification.Name(rawValue: "com.loudnate.LoopKit.AuthorizationStatusDidChangeNotification")
}


public enum HealthKitSampleStoreResult<T> {
    case success(T)
    case failure(HealthKitSampleStore.StoreError)
}


open class HealthKitSampleStore {
    public enum StoreError: Error {
        case authorizationDenied
        case healthKitError(HKError)
    }
    
    /// All the sample types we need permission to read
    @available(*, deprecated, message: "Use HealthKitSampleStore.getter:sampleType instead")
    public var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: sampleType)
    }
    
    /// All the sample types we need permission to share
    @available(*, deprecated, message: "Use HealthKitSampleStore.getter:sampleType instead")
    public var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: sampleType)
    }
    
    /// The sample type managed by this store
    public let sampleType: HKSampleType

    /// The health store used for underlying queries
    public let healthStore: HKHealthStore

    private let log = OSLog(category: "HealthKitSampleStore")

    public init(healthStore: HKHealthStore, type: HKSampleType, observationStart: Date) {
        self.healthStore = healthStore
        self.sampleType = type
        self.observationStart = observationStart

        if !authorizationRequired {
            createQuery()
        }
    }

    deinit {
        observerQuery = nil
    }

    // MARK: - Authorization

    /**
     Initializes the HealthKit authorization flow for all required sample types

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter completion: A closure called after authorization is completed. This closure takes two arguments:
        - success: Whether the authorization to share was successful
        - error:   An error object explaining why the authorization was unsuccessful
     */
    @available(*, deprecated, message: "Use HealthKitSampleStore.authorize(_:) instead")
    open func authorize(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        authorize { result in
            switch result {
            case .success:
                completion(true, nil)
            case .failure(let error):
                completion(false, error)
            }
        }
    }
    
    /// Requests authorization from HealthKit to share and read the sample type.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the authorization is completed
    /// - Parameter result: The authorization result
    open func authorize(_ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        healthStore.requestAuthorization(toShare: [sampleType], read: [sampleType]) { (completed, error) -> Void in
            if completed && !self.sharingDenied {
                self.createQuery()
                completion(.success(true))
            } else {
                let authError: StoreError
                
                if let error = error {
                    authError = .healthKitError(HKError(_nsError: error as NSError))
                } else {
                    authError = .authorizationDenied
                }
                
                completion(.failure(authError))
            }
            
            NotificationCenter.default.post(name: .StoreAuthorizationStatusDidChange, object: self)
        }
    }

    // MARK: - Query support

    /// The active observer query
    private var observerQuery: HKObserverQuery? {
        didSet {
            if let query = oldValue {
                healthStore.stop(query)
            }

            if let query = observerQuery {
                healthStore.execute(query)
            }
        }
    }

    /// The earliest sample date for which additions and deletions are observed
    public var observationStart: Date {
        didSet {
            // If we are now looking farther back, then reset the query
            if oldValue > observationStart {
                createQuery()
            }
        }
    }

    /// The last-retreived anchor from an anchored object query
    private var queryAnchor: HKQueryAnchor?

    /// Called in response to an update by the observer query
    ///
    /// - Parameters:
    ///   - query: The query which triggered the update
    ///   - error: An error during the update, if one occurred
    open func observeUpdates(to query: HKObserverQuery, error: Error?) {
        if error == nil {
            let anchoredObjectQuery = HKAnchoredObjectQuery(
                type: self.sampleType,
                predicate: query.predicate,
                anchor: self.queryAnchor,
                limit: HKObjectQueryNoLimit
            ) { (query, newSamples, deletedSamples, anchor, error) in
                self.log.debug("%@: anchor: %@", #function, String(describing: anchor))

                if let error = error {
                    self.log.error("%@: error executing anchoredObjectQuery: %@", String(describing: type(of: self)), error.localizedDescription)
                }

                self.processResults(from: query, added: newSamples ?? [], deleted: deletedSamples ?? [], error: error)
                self.queryAnchor = anchor
            }

            healthStore.execute(anchoredObjectQuery)
        }
    }

    /// Called in response to new results from an anchored object query
    ///
    /// - Parameters:
    ///   - query: The executed query
    ///   - added: An array of samples added
    ///   - deleted: An array of samples deleted
    ///   - error: An error from the query, if one occurred
    open func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], error: Error?) {
        // To be overridden
    }
}


// MARK: - Observation
extension HealthKitSampleStore {
    private func createQuery() {
        log.debug("%@: %@", String(describing: type(of: self)), #function)
        let predicate = HKQuery.predicateForSamples(withStart: observationStart, end: nil)

        observerQuery = HKObserverQuery(sampleType: sampleType, predicate: predicate) { [unowned self] (query, completionHandler, error) in
            self.log.debug("%@ notified with changes for %@", query, self.sampleType)
            self.observeUpdates(to: query, error: error)

            completionHandler()
        }

        enableBackgroundDelivery { (result) in
            switch result {
            case .failure(let error):
                self.log.error("Error enabling background delivery: %@", error.localizedDescription)
            case .success:
                self.log.debug("Enabled background delivery for %@", self.sampleType)
            }
        }
    }

    /// Enables the immediate background delivery of updates to samples from HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the request is completed
    /// - Parameter result: A boolean indicating the new background delivery state
    private func enableBackgroundDelivery(_ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { (enabled, error) in
            if let error = error {
                completion(.failure(.healthKitError(HKError(_nsError: error as NSError))))
            } else if enabled {
                completion(.success(true))
            } else {
                assertionFailure()
            }
        }
    }

    /// Disables the immediate background delivery of updates to samples from HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the request is completed
    /// - Parameter result: A boolean indicating the new background delivery state
    private func disableBackgroundDelivery(_ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        healthStore.disableBackgroundDelivery(for: sampleType) { (disabled, error) in
            if let error = error {
                completion(.failure(.healthKitError(HKError(_nsError: error as NSError))))
            } else if disabled {
                completion(.success(false))
            } else {
                assertionFailure()
            }
        }
    }
}


// MARK: - HKHealthStore helpers
extension HealthKitSampleStore {
    
    /// True if the user has explicitly denied access to any required share types
    public var sharingDenied: Bool {
        return healthStore.authorizationStatus(for: sampleType) == .sharingDenied
    }
    
    /// True if the store requires authorization
    public var authorizationRequired: Bool {
        return healthStore.authorizationStatus(for: sampleType) == .notDetermined
    }
    
    /**
     Queries the preferred unit for the authorized share types. If more than one unit is retrieved,
     then the completion contains just one of them.

     - parameter completion: A closure called after the query is completed. This closure takes two arguments:
        - unit:  The retrieved unit
        - error: An error object explaining why the retrieval was unsuccessful
     */
    @available(*, deprecated, message: "Use HealthKitSampleStore.preferredUnit(_:) instead")
    public func preferredUnit(_ completion: @escaping (_ unit: HKUnit?, _ error: Error?) -> Void) {
        preferredUnit { result in
            switch result {
            case .success(let unit):
                completion(unit, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    /// Queries the preferred unit for the sample type.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the query is completed
    /// - Parameter result: The query result
    public func preferredUnit(_ completion: @escaping (_ result: HealthKitSampleStoreResult<HKUnit>) -> Void) {
        let quantityTypes = [self.sampleType].flatMap { (sampleType) -> HKQuantityType? in
            return sampleType as? HKQuantityType
        }

        self.healthStore.preferredUnits(for: Set(quantityTypes)) { (quantityToUnit, error) -> Void in
            if let error = error {
                completion(.failure(.healthKitError(HKError(_nsError: error as NSError))))
            } else if let unit = quantityToUnit.values.first {
                completion(.success(unit))
            } else {
                assertionFailure()
            }
        }
    }
}


extension HealthKitSampleStore: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        * observerQuery: \(String(describing: observerQuery))
        * observationStart: \(observationStart)
        * authorizationRequired: \(authorizationRequired)
        """
    }
}


extension HealthKitSampleStore.StoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return NSLocalizedString("Authorization Denied", comment: "The error description describing when Health sharing was denied")
        case .healthKitError(let error):
            return error.localizedDescription
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .authorizationDenied:
            return NSLocalizedString("Please re-enable sharing in Health", comment: "The error recovery suggestion when Health sharing was denied")
        case .healthKitError(let error):
            return error.errorUserInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
        }
    }
}
