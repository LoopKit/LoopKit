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
    private let observerQueryUpdateHandlerQueue: DispatchQueue

    public enum StoreError: Error {
        case authorizationDenied
        case healthKitError(HKError)
    }
    
    /// The sample type managed by this store
    public let sampleType: HKSampleType

    /// The health store used for underlying queries
    public let healthStore: HKHealthStore
    
    /// Whether the store should fetch data that was written to HealthKit from current app
    private let observeHealthKitSamplesFromCurrentApp: Bool

    /// Whether the store should fetch data that was written to HealthKit from other apps
    private let observeHealthKitSamplesFromOtherApps: Bool

    /// Whether the store is observing changes to types
    public let observationEnabled: Bool

    /// For unit testing only.
    internal var testQueryStore: HKSampleQueryTestable?

    /// Allows for controlling uses of the system date in unit testing
    internal var test_currentDate: Date?

    internal func currentDate(timeIntervalSinceNow: TimeInterval = 0) -> Date {
        let date = test_currentDate ?? Date()
        return date.addingTimeInterval(timeIntervalSinceNow)
    }
    
    /// Allows unit test to inject a mock for HKObserverQuery
    internal var createObserverQuery: (HKSampleType, NSPredicate?, @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) -> HKObserverQuery = { (sampleType, predicate, updateHandler) in
        return HKObserverQuery(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
    }
    
    /// Allows unit test to inject a mock for HKAnchoredObjectQuery
    internal var createAnchoredObjectQuery: (HKSampleType, NSPredicate?, HKQueryAnchor?, Int, @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void) -> HKAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) in
        return HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
    }

    private let log: OSLog

    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromCurrentApp: Bool = true,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        type: HKSampleType,
        observationStart: Date,
        observationEnabled: Bool,
        test_currentDate: Date? = nil
    ) {
        self.healthStore = healthStore
        self.observeHealthKitSamplesFromCurrentApp = observeHealthKitSamplesFromCurrentApp
        self.observeHealthKitSamplesFromOtherApps = observeHealthKitSamplesFromOtherApps
        self.sampleType = type
        self.observationStart = observationStart
        self.observationEnabled = observationEnabled
        self.test_currentDate = test_currentDate
        self.lockedQueryAnchor = Locked<HKQueryAnchor?>(nil)

        self.log = OSLog(category: String(describing: Swift.type(of: self)))
 
        self.observerQueryUpdateHandlerQueue = DispatchQueue(label: "com.loopkit.HealthKitSampleStore.observerQueryUpdateHandlerQueue.\(Swift.type(of: self))", qos: .utility)
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
    ///   - read: Whether to request read authorization. Defaults to true.
    ///   - completion: A closure called after the authorization is completed
    ///   - result: The authorization result
    public func authorize(toShare: Bool = true, read: Bool = true, _ completion: @escaping (_ result: HealthKitSampleStoreResult<Bool>) -> Void) {
        healthStore.requestAuthorization(toShare: toShare ? [sampleType] : [], read: read ? [sampleType] : []) { (completed, error) -> Void in
            if completed && !self.sharingDenied {
                self.log.default("Authorize completed: creating HK query")
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

            // Do not remove this log: it actually triggers a query by calling preferredUnit, and can update the cache
            // And trigger a unit change notification after authorization happens.
            self.log.default("Checking units after authorization: %{public}@", String(describing: self.preferredUnit))
        }
    }

    // MARK: - Query support

    /// The active observer query
    internal var observerQuery: HKObserverQuery? {
        didSet {
            if let query = oldValue {
                healthStore.stop(query)
            }

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
    private let lockedQueryAnchor: Locked<HKQueryAnchor?>

    func queryAnchorDidChange() {
        // Subclasses can override
    }

    /// Called in response to an update by the observer query
    ///
    /// - Parameters:
    ///   - query: The query which triggered the update
    ///   - error: An error during the update, if one occurred
    internal final func observeUpdates(to query: HKObserverQuery, completionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) {

        if let error = error {
            self.log.error("Observer query %@ notified of error: %{public}@", query, String(describing: error))
            completionHandler()
            return
        }
        
        self.log.default("observeUpdates invoked - queueing handling")

        observerQueryUpdateHandlerQueue.async {

            let queryAnchor = self.queryAnchor
            
            self.log.default("%@ notified with changes. Fetching from: %{public}@", query, queryAnchor.map(String.init(describing:)) ?? "0")
            
            let semaphore = DispatchSemaphore(value: 0)

            let anchoredObjectQuery = self.createAnchoredObjectQuery(self.sampleType, query.predicate, queryAnchor, HKObjectQueryNoLimit) { [weak self] (query, newSamples, deletedSamples, anchor, error) in
                
                if let self = self {
                    self.anchoredObjectQueryResultsHandler(query: query, newSamples: newSamples, deletedSamples: deletedSamples, anchor: anchor, error: error) {
                        completionHandler()
                        semaphore.signal()
                    }
                } else {
                    completionHandler()
                    semaphore.signal()
                }
            }
            self.healthStore.execute(anchoredObjectQuery)
            
            semaphore.wait()
        }
    }
    
    private func anchoredObjectQueryResultsHandler(query: HKAnchoredObjectQuery, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, anchor: HKQueryAnchor?, error: Error?, completion: @escaping () -> Void) {
        if let error = error {
            self.log.error("Error from anchoredObjectQuery: anchor: %{public}@ error: %{public}@", String(describing: anchor), String(describing: error))
            completion()
            return
        }
        
        self.log.default("anchoredObjectQuery.resultsHandler: new: %{public}d deleted: %{public}d anchor: %{public}@", newSamples?.count ?? 0, deletedSamples?.count ?? 0, String(describing: anchor))
        
        guard let anchor = anchor else {
            self.log.error("anchoredObjectQueryResultsHandler called with no anchor")
            completion()
            return
        }

        self.processResults(from: query, added: newSamples ?? [], deleted: deletedSamples ?? [], anchor: anchor) { (success) in
            if success {
                // Do not advance anchor if we failed to update local cache
                self.queryAnchor = anchor
            }
            completion()
        }
    }

    /// Called in response to new results from an anchored object query
    ///
    /// - Parameters:
    ///   - query: The executed query
    ///   - added: An array of samples added
    ///   - deleted: An array of samples deleted
    ///   - error: An error from the query, if one occurred
    internal func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor, completion: @escaping (Bool) -> Void) {
        // To be overridden
        completion(true)
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


// MARK: - Query
extension HealthKitSampleStore {
    internal func predicateForSamples(withStart startDate: Date?, end endDate: Date?, options: HKQueryOptions = []) -> NSPredicate? {
        guard observeHealthKitSamplesFromCurrentApp || observeHealthKitSamplesFromOtherApps else {
            return nil
        }

        // Initial predicate is just the date range
        var predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: options)

        // If we don't want samples from the current app, then only query samples NOT from the default HKSource
        if !observeHealthKitSamplesFromCurrentApp {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSCompoundPredicate(notPredicateWithSubpredicate: HKQuery.predicateForObjects(from: HKSource.default()))])

        // Othewrise, if we don't want samples from other apps, then only query samples from the default HKSource
        } else if !observeHealthKitSamplesFromOtherApps {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, HKQuery.predicateForObjects(from: HKSource.default())])
        }

        return predicate
    }
}


// MARK: - Observation
extension HealthKitSampleStore {
    internal func createQuery() {
        log.debug("%@ [sampleType: %@]", #function, sampleType)
        log.debug("%@ [observationEnabled: %d]", #function, observationEnabled)
        log.debug("%@ [observeHealthKitSamplesFromCurrentApp: %d]", #function, observeHealthKitSamplesFromCurrentApp)
        log.debug("%@ [observeHealthKitSamplesFromOtherApps: %d]", #function, observeHealthKitSamplesFromOtherApps)
        log.debug("%@ [observationStart: %@]", #function, String(describing: observationStart))

        guard observationEnabled else {
            return
        }

        guard let predicate = predicateForSamples(withStart: observationStart, end: nil) else {
            return
        }

        observerQuery = createObserverQuery(sampleType, predicate) { [weak self] (query, completionHandler, error) in
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
    
    /// True if the user has explicitly authorized access to any required share types
    public var sharingAuthorized: Bool {
        return healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized
    }

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
