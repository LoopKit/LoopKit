//
//  HealthKitSampleStore.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import os.log

public protocol HKHealthStoreProtocol {
    func stop(_ query: HKQuery)
    func execute(_ query: HKQuery)
#if os(iOS)
    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency) async throws
#endif
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func save(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void)
    func save(_ object: HKObject, withCompletion completion: @escaping (Bool, Error?) -> Void)
    func deleteObjects(of objectType: HKObjectType, predicate: NSPredicate, withCompletion completion: @escaping (Bool, Int, Error?) -> Void)

    func cachedPreferredUnits(for quantityTypeIdentifier: HKQuantityTypeIdentifier) async -> HKUnit?
}

extension HKHealthStore: HKHealthStoreProtocol {
    public func cachedPreferredUnits(for quantityTypeIdentifier: HKQuantityTypeIdentifier) async -> HKUnit? {
        return HealthStoreUnitCache.unitCache(for: self).preferredUnit(for: quantityTypeIdentifier)
    }
}


public protocol HealthKitSampleStoreDelegate {
    func storeQueryAnchor(_ anchor: HKQueryAnchor)

    /// Called in response to new results from an anchored object query
    ///
    /// - Parameters:
    ///   - query: The executed query
    ///   - added: An array of samples added
    ///   - deleted: An array of samples deleted
    ///   - error: An error from the query, if one occurred
    func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor, completion: @escaping (Bool) -> Void)
}

extension Notification.Name {
    public static let StoreAuthorizationStatusDidChange = Notification.Name(rawValue: "com.loudnate.LoopKit.AuthorizationStatusDidChangeNotification")
}

public enum HealthKitSampleStoreResult<T> {
    case success(T)
    case failure(HealthKitSampleStore.StoreError)
}

public class HealthKitSampleStore {

    public enum StoreError: Error {
        case authorizationDenied
        case healthKitError(HKError)
    }

    public static let carbType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!
    public static let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!
    public static let insulinQuantityType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    /// The sample type managed by this store
    public let sampleType: HKSampleType

    /// The health store used for underlying queries
    public let healthStore: HKHealthStoreProtocol

    /// Whether the store should fetch data that was written to HealthKit from current app
    private let observeHealthKitSamplesFromCurrentApp: Bool

    /// Whether the store should fetch data that was written to HealthKit from other apps
    private let observeHealthKitSamplesFromOtherApps: Bool

    /// Whether the store is observing changes to types
    public let observationEnabled: Bool

    public var delegate: HealthKitSampleStoreDelegate?

    // Testing
    public var observerQueryType = HKObserverQuery.self
    public var anchoredObjectQueryType = HKAnchoredObjectQuery.self

    private let log: OSLog

    public init(
        healthStore: HKHealthStoreProtocol,
        observeHealthKitSamplesFromCurrentApp: Bool = true,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        type: HKSampleType,
        observationStart: Date? = nil,
        observationEnabled: Bool = true
    ) {
        self.healthStore = healthStore
        self.observeHealthKitSamplesFromCurrentApp = observeHealthKitSamplesFromCurrentApp
        self.observeHealthKitSamplesFromOtherApps = observeHealthKitSamplesFromOtherApps
        self.sampleType = type
        self.observationStart = observationStart ?? Date().addingTimeInterval(-.hours(24))
        self.observationEnabled = observationEnabled
        self.lockedQueryState = Locked<QueryState>(QueryState(anchorState: .uninitialized, authorizationDetermined: false))

        self.log = OSLog(category: String(describing: Swift.type(of: self)))
    }

    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
        observerQuery = nil
    }

    public func authorizationIsDetermined() {
        self.mutateQueryState { state in
            state.authorizationDetermined = true
        }

        // Do not remove this log: it actually triggers a query by calling preferredUnit, and can update the cache
        // And trigger a unit change notification after authorization happens.
        Task {
            let unit = await self.preferredUnit
            self.log.default("Checking units after authorization: %{public}@", String(describing: unit))
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
                log.debug("Executing observerQuery %@", String(describing: query))
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
                createQuery(from: "observartionStart")
            }
        }
    }

    private enum QueryAnchorState: Equatable {
        case uninitialized
        case initializationComplete(HKQueryAnchor?)

        var anchor: HKQueryAnchor? {
            switch self {
            case .uninitialized:
                return nil
            case.initializationComplete(let anchor):
                return anchor
            }
        }
    }

    /// The last-retreived anchor from an anchored object query
    internal var queryAnchor: HKQueryAnchor? {
        get {
            if case .initializationComplete(let anchor) = queryState.anchorState {
                return anchor
            } else {
                return nil
            }
        }
        set {
            mutateQueryState { state in
                state.anchorState = .initializationComplete(newValue)
                state.authorizationDetermined = !authorizationRequired
            }
        }
    }

    private struct QueryState: Equatable {
        var anchorState: QueryAnchorState
        var authorizationDetermined: Bool

        // ObserverQuery will fail if HKAuthorizationStatus is undetermined
        var readyToQuery: Bool {
            return anchorState != .uninitialized && authorizationDetermined
        }
    }

    private let lockedQueryState: Locked<QueryState>

    private var queryState: QueryState {
        return lockedQueryState.value
    }

    @discardableResult
    private func mutateQueryState(_ changes: (_ state: inout QueryState) -> Void) -> QueryState {
        return setQueryStateWithResult({ (state) -> QueryState in
            changes(&state)
            return state
        })
    }

    private func setQueryStateWithResult<ReturnType>(_ changes: (_ state: inout QueryState) -> ReturnType) -> ReturnType {
        var oldValue: QueryState!
        var returnType: ReturnType!
        let newValue = lockedQueryState.mutate { (state) in
            oldValue = state
            returnType = changes(&state)
        }

        guard oldValue != newValue else {
            return returnType
        }

        if let anchor = newValue.anchorState.anchor, anchor != oldValue.anchorState.anchor {
            delegate?.storeQueryAnchor(anchor)
        }

        if !oldValue.readyToQuery && newValue.readyToQuery {
            createQuery(from: "main")
        }

        if !oldValue.authorizationDetermined && newValue.authorizationDetermined {
            NotificationCenter.default.post(name: .StoreAuthorizationStatusDidChange, object: self)
        }

        return returnType
    }


    // Observation will not start until this is called. Pass nil to receive all the matching samples and recently deleted objects
    func setInitialQueryAnchor(_ anchor: HKQueryAnchor?) {
        queryAnchor = anchor
    }


    /// Called in response to an update by the observer query
    ///
    /// - Parameters:
    ///   - query: The query which triggered the update
    ///   - error: An error during the update, if one occurred
    internal final func observerQueryHandler(query: HKObserverQuery, observerQueryCompletionHandler: @escaping HKObserverQueryCompletionHandler, error: Error?) {

        if let error = error {
            log.error("Observer query %{public}@ notified of error: %{public}@", query, String(describing: error))
            observerQueryCompletionHandler()
            return
        }

        log.default("%{public}@ notified with changes. Fetching from: %{public}@", query, queryAnchor.map(String.init(describing:)) ?? "0")
        executeAnchorQuery(observerQuery: query, observerQueryCompletionHandler: observerQueryCompletionHandler)
    }

    internal final func executeAnchorQuery(observerQuery: HKObserverQuery, observerQueryCompletionHandler: @escaping HKObserverQueryCompletionHandler) {

        let batchSize = 500

        let anchoredObjectQuery = anchoredObjectQueryType.init(type: sampleType, predicate: observerQuery.predicate, anchor: queryAnchor, limit: batchSize) { [weak self] (query, newSamples, deletedSamples, anchor, error) in

            guard let self else {
                return
            }

            if let error = error {
                self.log.error("HKQuery: Error from anchoredObjectQuery: anchor: %{public}@ error: %{public}@", String(describing: anchor), String(describing: error))
                observerQueryCompletionHandler()
                return
            }

            guard let newSamples else {
                self.log.error("HKQuery: Error from anchoredObjectQuery: newSamples is nil")
                observerQueryCompletionHandler()
                return
            }

            guard let deletedSamples else {
                self.log.error("HKQuery: Error from anchoredObjectQuery: deletedSamples is nil")
                observerQueryCompletionHandler()
                return
            }

            guard let anchor = anchor else {
                self.log.error("HKQuery: anchoredObjectQueryResultsHandler called with no anchor")
                observerQueryCompletionHandler()
                return
            }

            self.log.default("AnchorQuery results new: %{public}d deleted: %{public}d anchor: %{public}@", newSamples.count, deletedSamples.count, anchor.description)

            guard anchor != self.queryAnchor else {
                self.log.default("Skipping processing results from anchored object query, as anchor was already processed")
                observerQueryCompletionHandler()
                return
            }

            if let delegate {
                delegate.processResults(from: query, added: newSamples, deleted: deletedSamples, anchor: anchor) { (success) in
                    if success {
                        // Do not advance anchor if we failed to update local cache
                        self.queryAnchor = anchor

                        if newSamples.count + deletedSamples.count >= batchSize {
                            self.executeAnchorQuery(observerQuery: observerQuery, observerQueryCompletionHandler: observerQueryCompletionHandler)
                        } else {
                            observerQueryCompletionHandler()
                        }
                    } else {
                        observerQueryCompletionHandler()
                    }
                }
            } else {
                observerQueryCompletionHandler()
            }
        }

        log.default("HKQuery: Executing anchored object query")
        healthStore.execute(anchoredObjectQuery)
    }

    /// The preferred unit for the sample type
    ///
    /// The unit may be nil if the health store times out while fetching or the sample type is unsupported
    var preferredUnit: HKUnit? {
        get async {
            let identifier = HKQuantityTypeIdentifier(rawValue: sampleType.identifier)
            return await healthStore.cachedPreferredUnits(for: identifier)
        }
    }
}


// MARK: - Unit Test Support
extension HealthKitSampleStore: HKSampleQueryTestable {
    func executeSampleQuery(
        for type: HKSampleType,
        matching predicate: NSPredicate,
        limit: Int = HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor]? = nil,
        resultsHandler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void)
    {
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)
        healthStore.execute(query)
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
    internal func createQuery(from: String) {
        log.debug("%@ [from: %@]", #function, from)
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

        // Assigning observerQuery starts the query
        observerQuery = observerQueryType.init(sampleType: sampleType, predicate: predicate) { [weak self] (query, completionHandler, error) in
            self?.observerQueryHandler(query: query, observerQueryCompletionHandler: completionHandler, error: error)
        }

#if os(iOS)
        Task {
            do {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
            } catch {
                self.log.error("Error enabling background delivery: %@", error.localizedDescription)
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
