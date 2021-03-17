//
//  GlucoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import HealthKit
import os.log

public protocol GlucoseStoreDelegate: AnyObject {

    /**
     Informs the delegate that the glucose store has updated glucose data.

     - Parameter glucoseStore: The glucose store that has updated glucose data.
     */
    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore)

}

/**
 Manages storage, retrieval, and calculation of glucose data.

 There are three tiers of storage:

 * Persistant cache, stored in Core Data, used to ensure access if the app is suspended and re-launched while the Health database
 * is protected and to provide data for upload to remote data services. Backfilled from HealthKit data up to observation interval.
```
 0    [max(cacheLength, momentumDataInterval, observationInterval)]
 |––––|
```
 * HealthKit data, managed by the current application
```
 0    [managedDataInterval?]
 |––––––––––––|
```
 * HealthKit data, managed by the manufacturer's application
```
      [managedDataInterval?]           [maxPurgeInterval]
              |–––––––––--->
```
 */
public final class GlucoseStore: HealthKitSampleStore {

    /// Notification posted when glucose samples were changed, either via direct add or from HealthKit
    public static let glucoseSamplesDidChange = NSNotification.Name(rawValue: "com.loopkit.GlucoseStore.glucoseSamplesDidChange")

    public weak var delegate: GlucoseStoreDelegate?

    private let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!

    /// The oldest interval to include when purging managed data
    private let maxPurgeInterval: TimeInterval = TimeInterval(hours: 24) * 7

    /// The interval before which glucose values should be purged from HealthKit. If nil, glucose values are not purged.
    public var managedDataInterval: TimeInterval? {
        get {
            return lockedManagedDataInterval.value
        }
        set {
            lockedManagedDataInterval.value = newValue
        }
    }
    private let lockedManagedDataInterval = Locked<TimeInterval?>(nil)

    /// The interval of glucose data to keep in cache
    public let cacheLength: TimeInterval

    /// The interval of glucose data to use for momentum calculation
    public let momentumDataInterval: TimeInterval

    /// The interval to observe HealthKit data to populate the cache
    public let observationInterval: TimeInterval

    private let queue = DispatchQueue(label: "com.loopkit.GlucoseStore.queue", qos: .utility)

    private let log = OSLog(category: "GlucoseStore")

    /// The most-recent glucose value.
    public private(set) var latestGlucose: GlucoseSampleValue? {
        get {
            return lockedLatestGlucose.value
        }
        set {
            lockedLatestGlucose.value = newValue
        }
    }
    private let lockedLatestGlucose = Locked<GlucoseSampleValue?>(nil)

    private let cacheStore: PersistenceController

    private let provenanceIdentifier: String

    static let healthKitQueryAnchorMetadataKey = "com.loopkit.GlucoseStore.hkQueryAnchor"

    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 60 /* minutes */ * 60 /* seconds */,
        momentumDataInterval: TimeInterval = 15 /* minutes */ * 60 /* seconds */,
        observationInterval: TimeInterval? = nil,
        provenanceIdentifier: String
    ) {
        let cacheLength = max(cacheLength, momentumDataInterval, observationInterval ?? 0)

        self.cacheStore = cacheStore
        self.momentumDataInterval = momentumDataInterval

        self.cacheLength = cacheLength
        self.observationInterval = observationInterval ?? cacheLength
        self.provenanceIdentifier = provenanceIdentifier

        super.init(healthStore: healthStore,
                   observeHealthKitSamplesFromCurrentApp: false,
                   observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
                   type: glucoseType,
                   observationStart: Date(timeIntervalSinceNow: -self.observationInterval),
                   observationEnabled: observationEnabled)

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            guard error == nil else {
                semaphore.signal()
                return
            }

            cacheStore.fetchAnchor(key: GlucoseStore.healthKitQueryAnchorMetadataKey) { (anchor) in
                self.queue.async {
                    self.queryAnchor = anchor

                    self.updateLatestGlucose()

                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
    }

    // MARK: - HealthKitSampleStore

    override func queryAnchorDidChange() {
        cacheStore.storeAnchor(queryAnchor, key: GlucoseStore.healthKitQueryAnchorMetadataKey)
    }

    override func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor, completion: @escaping (Bool) -> Void) {
        queue.async {
            guard anchor != self.queryAnchor else {
                self.log.default("Skipping processing results from anchored object query, as anchor was already processed")
                completion(true)
                return
            }

            var changed = false
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    // Add new samples
                    if let samples = added as? [HKQuantitySample] {
                        for sample in samples {
                            if try self.addGlucoseSample(for: sample) {
                                self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                                changed = true
                            } else {
                                self.log.default("Sample %@ from HKAnchoredObjectQuery already present in cache", sample.uuid.uuidString)
                            }
                        }
                    }

                    // Delete deleted samples
                    let count = try self.deleteGlucoseSamples(withUUIDs: deleted.map { $0.uuid })
                    if count > 0 {
                        self.log.debug("Deleted %d samples from cache from HKAnchoredObjectQuery", count)
                        changed = true
                    }

                    guard changed else {
                        return
                    }

                    error = self.cacheStore.save()
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if error != nil {
                completion(false)
                return
            }

            if !changed {
                completion(true)
                return
            }

            // Purge expired managed data from HealthKit
            if let newestStartDate = added.map({ $0.startDate }).max() {
                self.purgeExpiredManagedDataFromHealthKit(before: newestStartDate)
            }

            self.handleUpdatedGlucoseData(updateSource: .queriedByHealthKit)
            completion(true)
        }
    }
}

// MARK: - Fetching

extension GlucoseStore {
    /// Retrieves glucose samples within the specified date range.
    ///
    /// - Parameters:
    ///   - start: The earliest date of glucose samples to retrieve, if provided.
    ///   - end: The latest date of glucose samples to retrieve, if provided.
    ///   - completion: A closure called once the glucose samples have been retrieved.
    ///   - result: An array of glucose samples, in chronological order by startDate, or error.
    public func getGlucoseSamples(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        queue.async {
            completion(self.getGlucoseSamples(start: start, end: end))
        }
    }

    private func getGlucoseSamples(start: Date? = nil, end: Date? = nil) -> Result<[StoredGlucoseSample], Error> {
        dispatchPrecondition(condition: .onQueue(queue))

        var samples: [StoredGlucoseSample] = []
        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                samples = try self.getCachedGlucoseObjects(start: start, end: end).map { StoredGlucoseSample(managedObject: $0) }
            } catch let coreDataError {
                error = coreDataError
            }
        }

        if let error = error {
            return .failure(error)
        }

        return .success(samples)
    }

    private func getCachedGlucoseObjects(start: Date? = nil, end: Date? = nil) throws -> [CachedGlucoseObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        var predicates: [NSPredicate] = []
        if let start = start {
            predicates.append(NSPredicate(format: "startDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate < %@", end as NSDate))
        }

        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        request.predicate = (predicates.count > 1) ? NSCompoundPredicate(andPredicateWithSubpredicates: predicates) : predicates.first
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
    }

    private func updateLatestGlucose() {
        dispatchPrecondition(condition: .onQueue(queue))

        cacheStore.managedObjectContext.performAndWait {
            var latestGlucose: StoredGlucoseSample?

            do {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                request.fetchLimit = 1

                let objects = try self.cacheStore.managedObjectContext.fetch(request)
                latestGlucose = objects.first.map { StoredGlucoseSample(managedObject: $0) }
            } catch let error {
                self.log.error("Unable to fetch latest glucose object: %@", String(describing: error))
            }

            self.latestGlucose = latestGlucose
        }
    }
}

// MARK: - Modification

extension GlucoseStore {
    /// Add glucose samples to store.
    ///
    /// - Parameters:
    ///   - samples: The new glucose samples to add to the store.
    ///   - completion: A closure called once the glucose samples have been stored.
    ///   - result: An array of glucose samples that were stored, or error.
    public func addGlucoseSamples(_ samples: [NewGlucoseSample], completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        guard !samples.isEmpty else {
            completion(.success([]))
            return
        }

        queue.async {
            var storedSamples: [StoredGlucoseSample] = []
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    // Filter samples to ensure no duplicate sync identifiers nor existing sample with matching sync identifier for our provenance identifier
                    var syncIdentifiers = Set<String>()
                    let samples: [NewGlucoseSample] = try samples.compactMap { sample in
                        guard syncIdentifiers.insert(sample.syncIdentifier).inserted else {
                            self.log.default("Skipping adding glucose sample due to duplicate sync identifier: %{public}@", sample.syncIdentifier)
                            return nil
                        }

                        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "provenanceIdentifier == %@", self.provenanceIdentifier),
                                                                                                NSPredicate(format: "syncIdentifier == %@", sample.syncIdentifier)])
                        request.fetchLimit = 1

                        guard try self.cacheStore.managedObjectContext.count(for: request) == 0 else {
                            self.log.default("Skipping adding glucose sample due to existing cached sync identifier: %{public}@", sample.syncIdentifier)
                            return nil
                        }

                        return sample
                    }
                    guard !samples.isEmpty else {
                        return
                    }

                    let objects: [CachedGlucoseObject] = samples.map { sample in
                        let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                        object.create(from: sample, provenanceIdentifier: self.provenanceIdentifier)
                        return object
                    }

                    error = self.cacheStore.save()
                    if error != nil {
                        return
                    }

                    self.saveSamplesToHealthKit(samples, objects: objects)

                    storedSamples = objects.map { StoredGlucoseSample(managedObject: $0) }
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            self.handleUpdatedGlucoseData(updateSource: .changedInApp)
            completion(.success(storedSamples))
        }
    }

    private func saveSamplesToHealthKit(_ samples: [NewGlucoseSample], objects: [CachedGlucoseObject]) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard !samples.isEmpty else {
            return
        }

        let quantitySamples = samples.map { $0.quantitySample }
        var error: Error?

        // Save objects to HealthKit, log any errors, but do not fail
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.healthStore.save(quantitySamples) { (_, healthKitError) in
            error = healthKitError
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        if let error = error {
            self.log.error("Error saving HealthKit objects: %@", String(describing: error))
            return
        }

        // Update Core Data with the changes, log any errors, but do not fail
        for (object, quantitySample) in zip(objects, quantitySamples) {
            object.uuid = quantitySample.uuid
        }
        if let error = self.cacheStore.save() {
            self.log.error("Error updating CachedGlucoseObjects after saving HealthKit objects: %@", String(describing: error))
            objects.forEach { $0.uuid = nil }
        }
    }

    private func addGlucoseSample(for sample: HKQuantitySample) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Are there any objects matching the UUID?
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", sample.uuid as NSUUID)
        request.fetchLimit = 1

        let count = try cacheStore.managedObjectContext.count(for: request)
        guard count == 0 else {
            return false
        }

        // Add an object for this UUID
        let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
        object.create(from: sample)

        return true
    }

    private func deleteGlucoseSamples(withUUIDs uuids: [UUID], batchSize: Int = 500) throws -> Int {
        dispatchPrecondition(condition: .onQueue(queue))

        var count = 0
        for batch in uuids.chunked(into: batchSize) {
            let predicate = NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID })
            count += try cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)
        }
        return count
    }

    ///
    /// - Parameters:
    ///   - since: Only consider glucose valid after or at this date
    /// - Returns: The latest CGM glucose, if available in the time period specified
    public func getLatestCGMGlucose(since: Date, completion: @escaping (_ result: Result<StoredGlucoseSample?, Error>) -> Void) {
        queue.async {
            self.cacheStore.managedObjectContext.performAndWait {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = NSPredicate(format: "startDate >= %@ AND wasUserEntered == NO", since as NSDate)
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
                request.fetchLimit = 1

                do {
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    let samples = objects.map { StoredGlucoseSample(managedObject: $0) }
                    completion(.success(samples.first))
                } catch let error {
                    self.log.error("Error in getLatestCGMGlucose: %@", String(describing: error))
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Watch Synchronization

extension GlucoseStore {

    /// Get glucose samples in main app to deliver to Watch extension
    public func getSyncGlucoseSamples(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: Result<[StoredGlucoseSample], Error>) -> Void) {
        queue.async {
            var samples: [StoredGlucoseSample] = []
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    samples = try self.getCachedGlucoseObjects(start: start, end: end).map { StoredGlucoseSample(managedObject: $0) }
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(samples))
        }
    }

    /// Store glucose samples in Watch extension
    public func setSyncGlucoseSamples(_ objects: [StoredGlucoseSample], completion: @escaping (Error?) -> Void) {
        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                guard !objects.isEmpty else {
                    return
                }

                objects.forEach {
                    let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: $0)
                }

                error = self.cacheStore.save()
            }

            if let error = error {
                completion(error)
                return
            }

            self.handleUpdatedGlucoseData(updateSource: .changedInApp)
            completion(nil)
        }
    }
}

// MARK: - Cache Management

extension GlucoseStore {
    public var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
    }

    /// Purge all glucose samples from the glucose store and HealthKit (matching the specified device predicate).
    ///
    /// - Parameters:
    ///   - healthKitPredicate: The predicate to use in matching HealthKit glucose objects.
    ///   - completion: The completion handler returning any error.
    public func purgeAllGlucoseSamples(healthKitPredicate: NSPredicate, completion: @escaping (Error?) -> Void) {
        queue.async {
            let storeError = self.purgeCachedGlucoseObjects()
            self.healthStore.deleteObjects(of: self.glucoseType, predicate: healthKitPredicate) { _, _, healthKitError in
                self.queue.async {
                    if let error = storeError ?? healthKitError {
                        completion(error)
                        return
                    }

                    self.handleUpdatedGlucoseData(updateSource: .changedInApp)
                    completion(nil)
                }
            }
        }
    }

    private func purgeExpiredCachedGlucoseObjects() {
        purgeCachedGlucoseObjects(before: earliestCacheDate)
    }

    /// Purge cached glucose objects from the glucose store.
    ///
    /// - Parameters:
    ///   - date: Purge cached glucose objects with start date before this date.
    ///   - completion: The completion handler returning any error.
    public func purgeCachedGlucoseObjects(before date: Date? = nil, completion: @escaping (Error?) -> Void) {
        queue.async {
            if let error = self.purgeCachedGlucoseObjects(before: date) {
                completion(error)
                return
            }
            self.handleUpdatedGlucoseData(updateSource: .changedInApp)
            completion(nil)
        }
    }

    @discardableResult
    private func purgeCachedGlucoseObjects(before date: Date? = nil) -> Error? {
        dispatchPrecondition(condition: .onQueue(queue))

        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                var predicate: NSPredicate?
                if let date = date {
                    predicate = NSPredicate(format: "startDate < %@", date as NSDate)
                }
                let count = try cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)
                self.log.default("Purged %d CachedGlucoseObjects", count)
            } catch let coreDataError {
                self.log.error("Unable to purge CachedGlucoseObjects: %{public}@", String(describing: error))
                error = coreDataError
            }
        }

        return error
    }

    private func purgeExpiredManagedDataFromHealthKit(before date: Date) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let managedDataInterval = managedDataInterval else {
            return
        }

        let end = min(Date(timeIntervalSinceNow: -managedDataInterval), date)
        let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maxPurgeInterval), end: end)
        healthStore.deleteObjects(of: glucoseType, predicate: predicate) { (success, count, error) -> Void in
            // error is expected and ignored if protected data is unavailable
            if success {
                self.log.debug("Successfully purged %d HealthKit objects older than %{public}@", count, String(describing: end))
            }
        }
    }

    private func handleUpdatedGlucoseData(updateSource: UpdateSource) {
        dispatchPrecondition(condition: .onQueue(queue))

        self.purgeExpiredCachedGlucoseObjects()
        self.updateLatestGlucose()

        NotificationCenter.default.post(name: GlucoseStore.glucoseSamplesDidChange, object: self, userInfo: [GlucoseStore.notificationUpdateSourceKey: updateSource.rawValue])
        delegate?.glucoseStoreHasUpdatedGlucoseData(self)
    }
}

// MARK: - Math

extension GlucoseStore {
    /// Calculates the momentum effect for recent glucose values.
    ///
    /// The duration of effect data returned is determined by the `momentumDataInterval`, and the delta between data points is 5 minutes.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - completion: A closure called once the calculation has completed.
    ///   - result: The calculated effect values, or an empty array if the glucose data isn't suitable for momentum calculation, or error.
    public func getRecentMomentumEffect(_ completion: @escaping (_ result: Result<[GlucoseEffect], Error>) -> Void) {
        getGlucoseSamples(start: Date(timeIntervalSinceNow: -momentumDataInterval)) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let samples):
                let effects = samples.linearMomentumEffect(
                    duration: self.momentumDataInterval,
                    delta: TimeInterval(minutes: 5)
                )
                completion(.success(effects))
            }
        }
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose that counteract the specified effects.
    ///
    /// - Parameters:
    ///   - start: The earliest date of glucose samples to include.
    ///   - end: The latest date of glucose samples to include, if provided.
    ///   - effects: Glucose effects to be countered, in chronological order, and counteraction effects calculated.
    ///   - completion: A closure called once the glucose samples have been retrieved and counteraction effects calculated.
    ///   - result: An array of glucose effect velocities describing the change in glucose samples compared to the specified glucose effects, or error.
    public func getCounteractionEffects(start: Date, end: Date? = nil, to effects: [GlucoseEffect], _ completion: @escaping (_ result: Result<[GlucoseEffectVelocity], Error>) -> Void) {
        getGlucoseSamples(start: start, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let samples):
                completion(.success(self.counteractionEffects(for: samples, to: effects)))
            }
        }
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose that counteract the specified effects.
    ///
    /// - Parameter:
    ///   - samples: The observed timeline of samples.
    ///   - effects: An array of velocities describing the change in glucose samples compared to the specified effects
    public func counteractionEffects<Sample: GlucoseSampleValue>(for samples: [Sample], to effects: [GlucoseEffect]) -> [GlucoseEffectVelocity] {
        samples.counteractionEffects(to: effects)
    }
}

// MARK: - Remote Data Service Query

extension GlucoseStore {
    public struct QueryAnchor: RawRepresentable {
        public typealias RawValue = [String: Any]

        internal var modificationCounter: Int64

        public init() {
            self.modificationCounter = 0
        }

        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            return rawValue
        }
    }

    public enum GlucoseQueryResult {
        case success(QueryAnchor, [StoredGlucoseSample])
        case failure(Error)
    }

    public func executeGlucoseQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (GlucoseQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredGlucoseSample]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, []))
                return
            }

            self.cacheStore.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored.compactMap { StoredGlucoseSample(managedObject: $0) })
                } catch let error {
                    queryError = error
                    return
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryResult))
        }
    }
}

// MARK: - Critical Event Log Export

extension GlucoseStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Glucoses.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.cacheStore.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.cacheStore.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: OutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder.encode(objects)

                    modificationCounter = objects.last!.modificationCounter

                    progress.completedUnitCount += Int64(objects.count) * exportProgressUnitCountPerObject
                } catch let fetchError {
                    error = fetchError
                }
            }
        }

        if let closeError = encoder.close(), error == nil {
            error = closeError
        }

        return error
    }

    private func exportDatePredicate(startDate: Date, endDate: Date? = nil) -> NSPredicate {
        var predicate = NSPredicate(format: "startDate >= %@", startDate as NSDate)
        if let endDate = endDate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "startDate < %@", endDate as NSDate)])
        }
        return predicate
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension GlucoseStore {
    public func addNewGlucoseSamples(samples: [NewGlucoseSample], completion: @escaping (Error?) -> Void) {
        guard !samples.isEmpty else {
            completion(nil)
            return
        }

        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                for sample in samples {
                    let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                    object.create(from: sample, provenanceIdentifier: self.provenanceIdentifier)
                }
                error = self.cacheStore.save()
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d CachedGlucoseObjects", samples.count)
            self.delegate?.glucoseStoreHasUpdatedGlucoseData(self)
            completion(nil)
        }
    }
}

// MARK: - Issue Report

extension GlucoseStore {
    /// Generates a diagnostic report about the current state.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        queue.async {
            var report: [String] = [
                "## GlucoseStore",
                "",
                "* latestGlucoseValue: \(String(reflecting: self.latestGlucose))",
                "* managedDataInterval: \(self.managedDataInterval ?? 0)",
                "* cacheLength: \(self.cacheLength)",
                "* momentumDataInterval: \(self.momentumDataInterval)",
                "* observationInterval: \(self.observationInterval)",
                super.debugDescription,
                "",
                "### cachedGlucoseSamples",
            ]

            switch self.getGlucoseSamples(start: Date(timeIntervalSinceNow: -.hours(24))) {
            case .failure(let error):
                report.append("Error: \(error)")
            case .success(let samples):
                for sample in samples {
                    report.append(String(describing: sample))
                }
            }

            report.append("")

            completionHandler(report.joined(separator: "\n"))
        }
    }
}
