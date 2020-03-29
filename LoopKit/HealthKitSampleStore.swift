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


public class HealthKitSampleStore {
    /// Describes the source of an update notification. Value is of type `UpdateSource.RawValue`
    public static let notificationUpdateSourceKey = "com.loopkit.UpdateSource"

    public enum StoreError: Error {
        case authorizationDenied
        case healthKitError(HKError)
    }
    
    /// The sample type managed by this store
    public let sampleType: HKSampleType

    /// The health store used for underlying queries
    public let healthStore: HKHealthStore

    /// Whether the store is observing changes to types
    public let observationEnabled: Bool

    /// The last observer query completion, stored until the next anchored object query returns
    private var observerQueryCompletionHandler: HKObserverQueryCompletionHandler? {
        didSet {
            oldValue?()
        }
    }

    /// For unit testing only.
    internal var testQueryStore: HKSampleQueryTestable?

    /// Allows for controlling uses of the system date in unit testing
    internal var test_currentDate: Date?

    internal func currentDate(timeIntervalSinceNow: TimeInterval = 0) -> Date {
        let date = test_currentDate ?? Date()
        return date.addingTimeInterval(timeIntervalSinceNow)
    }

    private let log: OSLog

    public init(
        healthStore: HKHealthStore,
        type: HKSampleType,
        observationStart: Date,
        observationEnabled: Bool,
        test_currentDate: Date? = nil
    ) {
        self.healthStore = healthStore
        self.sampleType = type
        self.observationStart = observationStart
        self.observationEnabled = observationEnabled
        self.test_currentDate = test_currentDate
        self.lockedQueryAnchor = Locked<HKQueryAnchor?>(nil)

        self.log = OSLog(category: String(describing: Swift.type(of: self)))
    }

    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
        observerQuery = nil
    }

    // MARK: - Authorization
    
    /// Requests authorization from HealthKit to share and read the sample type.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - toShare: Whether to request write authorization. Defaults to true.
    ///   - completion: A closure called after the authorization is completed
    ///   - result: The authorization result
    public func authorize(toShare: Bool = true, _ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        healthStore.requestAuthorization(toShare: toShare ? [sampleType] : [], read: [sampleType]) { (completed, error) -> Void in
            if completed && !self.sharingDenied {
                self.log.default("authorize completed: creating HK query")
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

            // Clear any existing completion handler (after calling it)
            observerQueryCompletionHandler = nil

            if let query = observerQuery {
                log.debug("Executing observerQuery %@", query)
                healthStore.execute(query)
            }
        }
    }

    /// The earliest sample date for which additions and deletions are observed
    public internal(set) var observationStart: Date {
        didSet {
            // If we are now looking farther back, then reset the query
            if oldValue > observationStart {
                log.default("observationStart changed: creating HK query")
                createQuery()
            }
        }
    }

    /// The last-retreived anchor from an anchored object query
    internal var queryAnchor: HKQueryAnchor? {
        get {
            return lockedQueryAnchor.value
        }
        set {
            var changed: Bool = false
            lockedQueryAnchor.mutate { (anchor) in
                if anchor != newValue {
                    anchor = newValue
                    changed = true
                }
            }
            if changed {
                queryAnchorDidChange()
            }
        }
    }
    internal let lockedQueryAnchor: Locked<HKQueryAnchor?>

    func queryAnchorDidChange() {
        // Subclasses can override
    }

    /// Called in response to an update by the observer query
    ///
    /// - Parameters:
    ///   - query: The query which triggered the update
    ///   - error: An error during the update, if one occurred
    internal func observeUpdates(to query: HKObserverQuery, completionHandler: HKObserverQueryCompletionHandler?, error: Error?) {
        if let error = error {
            self.log.error("%@ notified with changes with error: %{public}@", query, String(describing: error))
            return
        }

        // Hold the completion handler (calling any existing ones) until our next anchored object query returns
        self.observerQueryCompletionHandler = completionHandler

        let queryAnchor = self.queryAnchor
        log.default("%@ notified with changes. Fetching from: %{public}@", query, queryAnchor.map(String.init(describing:)) ?? "0")

        createAnchoredObjectQuery(predicate: query.predicate, anchor: queryAnchor)
    }

    private final func anchoredObjectQueryResultsHandler(query: HKAnchoredObjectQuery, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, anchor: HKQueryAnchor?, error: Error?) {
        log.default("anchoredObjectQuery.resultsHandler: new: %{public}d deleted: %{public}d anchor: %{public}@ error: %{public}@", newSamples?.count ?? 0, deletedSamples?.count ?? 0, String(describing: anchor), String(describing: error))

        // Clear any existing completion handler (after calling it)
        observerQueryCompletionHandler = nil

        processResults(from: query, added: newSamples ?? [], deleted: deletedSamples ?? [], error: error)

        if anchor != nil {
            queryAnchor = anchor
        }
    }

    /// Called in response to new results from an anchored object query
    ///
    /// - Parameters:
    ///   - query: The executed query
    ///   - added: An array of samples added
    ///   - deleted: An array of samples deleted
    ///   - error: An error from the query, if one occurred
    internal func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], error: Error?) {
        // To be overridden
    }

    /// The preferred unit for the sample type
    ///
    /// The unit may be nil if the health store times out while fetching or the sample type is unsupported
    public var preferredUnit: HKUnit? {
        let identifier = HKQuantityTypeIdentifier(rawValue: sampleType.identifier)
        return HealthStoreUnitCache.unitCache(for: healthStore).preferredUnit(for: identifier)
    }
}


// MARK: - Unit Test Support
extension HealthKitSampleStore: HKSampleQueryTestable {
    func executeSampleQuery(
        for type: HKSampleType,
        matching predicate: NSPredicate,
        limit: Int = HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void
    ) {
        if let tester = testQueryStore {
            tester.executeSampleQuery(for: type, matching: predicate, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
        } else {
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
            healthStore.execute(query)
        }
    }
}


// MARK: - Observation
extension HealthKitSampleStore {
    internal func createQuery() {
        log.default("%@ [observationEnabled: %{public}d]", #function, observationEnabled)

        guard observationEnabled else {
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: observationStart, end: nil)

        createObserverQuery(predicate: predicate)
    }

    private func createObserverQuery(predicate: NSPredicate) {
        observerQuery = HKObserverQuery(sampleType: sampleType, predicate: predicate) { [weak self] (query, completionHandler, error) in
            self?.observeUpdates(to: query, completionHandler: completionHandler, error: error)
        }

        enableBackgroundDelivery { (result) in
            switch result {
            case .failure(let error):
                self.log.error("Error enabling background delivery: %@", error.localizedDescription)
            case .success:
                self.log.default("Enabled background delivery for %{public}@", self.sampleType)
            }
        }
    }

    private func createAnchoredObjectQuery(predicate: NSPredicate?, anchor: HKQueryAnchor?) {
        let anchoredObjectQuery = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: anchor == nil ? predicate : nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { (query, newSamples, deletedSamples, anchor, error) in
            self.anchoredObjectQueryResultsHandler(query: query, newSamples: newSamples, deletedSamples: deletedSamples, anchor: anchor, error: error)
        }

        healthStore.execute(anchoredObjectQuery)
    }

    /// Enables the immediate background delivery of updates to samples from HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the request is completed
    /// - Parameter result: A boolean indicating the new background delivery state
    private func enableBackgroundDelivery(_ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        #if os(iOS)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { (enabled, error) in
                if let error = error {
                    completion(.failure(.healthKitError(HKError(_nsError: error as NSError))))
                } else if enabled {
                    completion(.success(true))
                } else {
                    assertionFailure()
                }
            }
        #endif
    }

    /// Disables the immediate background delivery of updates to samples from HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameter completion: A closure called after the request is completed
    /// - Parameter result: A boolean indicating the new background delivery state
    private func disableBackgroundDelivery(_ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        #if os(iOS)
            healthStore.disableBackgroundDelivery(for: sampleType) { (disabled, error) in
                if let error = error {
                    completion(.failure(.healthKitError(HKError(_nsError: error as NSError))))
                } else if disabled {
                    completion(.success(false))
                } else {
                    assertionFailure()
                }
            }
        #endif
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
    @available(*, deprecated, message: "Use HealthKitSampleStore.getter:preferredUnit instead")
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
    @available(*, deprecated, message: "Use HealthKitSampleStore.getter:preferredUnit instead")
    private func preferredUnit(_ completion: @escaping (_ result: HealthKitSampleStoreResult<HKUnit>) -> Void) {
        let quantityTypes = [self.sampleType].compactMap { (sampleType) -> HKQuantityType? in
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
        * observationEnabled: \(observationEnabled)
        * authorizationRequired: \(authorizationRequired)
        """
    }
}


extension HealthKitSampleStore.StoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return LocalizedString("Authorization Denied", comment: "The error description describing when Health sharing was denied")
        case .healthKitError(let error):
            return error.localizedDescription
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .authorizationDenied:
            return LocalizedString("Please re-enable sharing in Health", comment: "The error recovery suggestion when Health sharing was denied")
        case .healthKitError(let error):
            return error.errorUserInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
        }
    }
}
