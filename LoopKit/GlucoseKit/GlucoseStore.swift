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

public enum GlucoseStoreResult<T> {
    case success(T)
    case failure(Error)
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

    /// Notification posted when glucose samples were changed, either via add/replace/delete methods or from HealthKit
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

    private let dataAccessQueue = DispatchQueue(label: "com.loudnate.GlucoseKit.dataAccessQueue", qos: .utility)

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
    
    static let healthKitQueryAnchorMetadataKey = "com.loopkit.GlucoseStore.hkQueryAnchor"

    private let startAfterDatePredicate = NSPredicate(format: "startDate >= $start")

    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 60 /* minutes */ * 60 /* seconds */,
        momentumDataInterval: TimeInterval = 15 /* minutes */ * 60 /* seconds */,
        observationInterval: TimeInterval? = nil
    ) {
        let cacheLength = max(cacheLength, momentumDataInterval, observationInterval ?? 0)

        self.cacheStore = cacheStore
        self.momentumDataInterval = momentumDataInterval
        
        self.cacheLength = cacheLength
        self.observationInterval = observationInterval ?? cacheLength

        super.init(healthStore: healthStore, observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps, type: glucoseType, observationStart: Date(timeIntervalSinceNow: -self.observationInterval), observationEnabled: observationEnabled)

        
        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            cacheStore.fetchAnchor(key: GlucoseStore.healthKitQueryAnchorMetadataKey) { (anchor) in
                self.dataAccessQueue.async {
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
        dataAccessQueue.async {
            guard anchor != self.queryAnchor else {
                self.log.default("Skipping processing results from anchored object query, as anchor was already processed")
                completion(true)
                return
            }

            var newestSampleStartDateAddedByExternalSource: Date?
            var samplesAddedByExternalSourceWithinManagedDataInterval = false
            var cacheChanged = false

            // Added samples
            let samples = ((added as? [HKQuantitySample]) ?? []).filterDateRange(self.earliestCacheDate, nil)

            for sample in samples {
                if sample.sourceRevision.source != .default() {
                    newestSampleStartDateAddedByExternalSource = max(sample.startDate, newestSampleStartDateAddedByExternalSource  ?? .distantPast)
                    if let managedDataInterval = self.managedDataInterval, sample.startDate.timeIntervalSinceNow > -managedDataInterval {
                        samplesAddedByExternalSourceWithinManagedDataInterval = true
                    }
                }
            }

            switch self.addCachedObjects(for: samples) {
            case .success(let didCreate):
                cacheChanged = didCreate
            case .failure(let error):
                self.log.error("Samples added to HK could not added to cache: %{public}@", String(describing: error))
                completion(false)
                return
            }

            // Deleted samples
            self.log.debug("Starting deletion of %d samples", deleted.count)
            switch self.deleteCachedObjects(forSampleUUIDs: deleted.map({ $0.uuid })) {
            case .success(let cacheDeletedCount):
                if cacheDeletedCount > 0 {
                    cacheChanged = true
                }
                self.log.debug("Finished deletion: HK delete count = %d, cache delete count = %d", deleted.count, cacheDeletedCount)
            case .failure(let error):
                self.log.error("Samples deleted from HK could not be deleted from cache: %{public}@", String(describing: error))
                completion(false)
                return
            }

            if let startDate = newestSampleStartDateAddedByExternalSource {
                self.purgeOldGlucoseSamples(includingManagedDataBefore: startDate)
            }

            if cacheChanged {
                self.updateLatestGlucose()
            }

            if samplesAddedByExternalSourceWithinManagedDataInterval {
                NotificationCenter.default.post(name: GlucoseStore.glucoseSamplesDidChange, object: self, userInfo: [GlucoseStore.notificationUpdateSourceKey: UpdateSource.queriedByHealthKit.rawValue])
            }

            completion(true)
        }
    }
}

extension GlucoseStore {
    /// Add new glucose values to HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - glucose: A glucose sample to save
    ///   - completion: A closure called after the save completes
    ///   - result: The saved glucose value
    public func addGlucose(_ glucose: NewGlucoseSample, completion: @escaping (_ result: GlucoseStoreResult<GlucoseValue>) -> Void) {
        addGlucose([glucose]) { (result) in
            switch result {
            case .success(let values):
                completion(.success(values.first!))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Add new glucose values to HealthKit.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - values: An array of glucose samples to save
    ///   - completion: A closure called after the save completes
    ///   - result: The saved glucose values
    public func addGlucose(_ values: [NewGlucoseSample], completion: @escaping (_ result: GlucoseStoreResult<[GlucoseValue]>) -> Void) {
        guard values.count > 0 else {
            completion(.success([]))
            return
        }

        var glucose: [HKQuantitySample] = []

        // this isn't great that we're blocking the calling thread here?
        cacheStore.managedObjectContext.performAndWait {
            glucose = values.compactMap {
                guard self.cacheStore.managedObjectContext.cachedGlucoseObjectsWithSyncIdentifier($0.syncIdentifier, fetchLimit: 1).count == 0 else {
                    log.default("Skipping adding glucose value due to existing cached syncIdentifier: %{public}@", $0.syncIdentifier)
                    return nil
                }

                return $0.quantitySample
            }
        }

        delegate?.glucoseStoreHasUpdatedGlucoseData(self)

        healthStore.save(glucose) { (completed, error) in
            self.dataAccessQueue.async {
                if let error = error {
                    completion(.failure(error))
                } else if completed {
                    self.addCachedObjects(for: glucose)
                    self.purgeOldGlucoseSamples(includingManagedDataBefore: nil)
                    self.updateLatestGlucose()

                    completion(.success(glucose))
                    NotificationCenter.default.post(name: GlucoseStore.glucoseSamplesDidChange, object: self, userInfo: [GlucoseStore.notificationUpdateSourceKey: UpdateSource.changedInApp.rawValue])

                } else {
                    assertionFailure()
                }
            }
        }
    }


    /// Deletes glucose samples from both the CoreData cache and from HealthKit.
    ///
    /// - Parameters:
    ///   - cachePredicate: The predicate to use in matching CoreData glucose objects, or `nil` to match all.
    ///   - healthKitPredicate: The predicate to use in matching HealthKit glucose objects.
    ///   - completion: The completion handler for the result of the HealthKit object deletion.
    public func purgeGlucoseSamples(matchingCachePredicate cachePredicate: NSPredicate?, healthKitPredicate: NSPredicate, completion: @escaping (_ success: Bool, _ count: Int, _ error: Error?) -> Void) {
        dataAccessQueue.async {
            self.purgeCachedGlucoseObjects(matching: cachePredicate)
            self.healthStore.deleteObjects(of: self.glucoseType, predicate: healthKitPredicate, withCompletion: completion)
        }
    }

    /**
     Cleans the in-memory and managed HealthKit caches.
     
     *This method should only be called from the `dataAccessQueue`*
     */
    private func purgeOldGlucoseSamples(includingManagedDataBefore managedDataDate: Date?) {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        let cachePredicate = NSPredicate(format: "startDate < %@", earliestCacheDate as NSDate)
        purgeCachedGlucoseObjects(matching: cachePredicate)

        if let managedDataDate = managedDataDate, let managedDataInterval = managedDataInterval {
            let end = min(Date(timeIntervalSinceNow: -managedDataInterval), managedDataDate)

            let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maxPurgeInterval), end: end)

            healthStore.deleteObjects(of: glucoseType, predicate: predicate) { (success, count, error) -> Void in
                // error is expected and ignored if protected data is unavailable
                if success {
                    self.log.debug("Successfully purged %d HealthKit objects older than %{public}@", count, String(describing: end))
                }
            }
        }
    }

    /// Retrieves glucose values from either HealthKit or the in-memory cache.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - samples: An array of glucose values, in chronological order by startDate
    public func getCachedGlucoseSamples(start: Date, end: Date? = nil, completion: @escaping (_ samples: [StoredGlucoseSample]) -> Void) {
        #if os(iOS)
        // If we're within our observation duration, skip the HealthKit query
        guard start <= earliestObservationDate else {
            self.dataAccessQueue.async {
                let objects = self.getCachedGlucoseObjects(start: start, end: end)
                completion(objects)
            }
            return
        }
        #endif

        getGlucoseSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                completion(samples)
            case .failure:
                // Expected when database is inaccessible
                self.dataAccessQueue.async {
                    let objects = self.getCachedGlucoseObjects(start: start, end: end)
                    completion(objects)
                }
            }
        }
    }

    /// Retrieves glucose values from HealthKit within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - result: An array of glucose values, in chronological order by startDate
    public func getGlucoseSamples(start: Date, end: Date? = nil, completion: @escaping (_ result: GlucoseStoreResult<[StoredGlucoseSample]>) -> Void) {
        guard let predicate = predicateForSamples(withStart: start, end: end) else {
            completion(.success([]))
            return
        }

        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in
            if let error = error {
                completion(.failure(error))
            } else {
                let samples = samples as? [HKQuantitySample] ?? []
                completion(.success(samples.map { StoredGlucoseSample(sample: $0) }))
            }
        }

        healthStore.execute(query)
    }
}


// MARK: - Core Data
extension GlucoseStore {
    @discardableResult
    private func addCachedObjects(for samples: [HKQuantitySample]) -> Result<Bool,Error> {
        return addCachedObjects(for: samples.map { StoredGlucoseSample(sample: $0) })
    }

    /// Creates new cached glucose objects from samples if they're not already cached and within the cache interval
    ///
    /// - Parameter samples: The samples to cache
    /// - Returns: Result. If successful, bool indicates if any objects were created. Otherwise, failure returns error.
    @discardableResult
    private func addCachedObjects(for samples: [StoredGlucoseSample]) -> Result<Bool,Error> {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        var created = false
        var storageError: Error? = nil
        
        cacheStore.managedObjectContext.performAndWait {
            for sample in samples {
                guard
                    sample.startDate.timeIntervalSinceNow > -self.cacheLength,
                    self.cacheStore.managedObjectContext.cachedGlucoseObjectsWithUUID(sample.sampleUUID, fetchLimit: 1).count == 0
                else {
                    continue
                }

                let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                object.update(from: sample)
                created = true
            }

            if created {
                self.cacheStore.save { (error) in
                    storageError = error
                }
            }
        }
        
        if let error = storageError {
            return .failure(error)
        } else {
            return .success(created)
        }
    }

    private func getCachedGlucoseObjects(start: Date, end: Date? = nil) -> [StoredGlucoseSample] {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))
        let predicate: NSPredicate

        if let end = end {
            predicate = NSPredicate(format: "startDate >= %@ AND startDate <= %@", start as NSDate, end as NSDate)
        } else {
            predicate = NSPredicate(format: "startDate >= %@", start as NSDate)
        }

        return getCachedGlucoseObjects(matching: predicate)
    }

    /// Fetches glucose samples from the cache that match the given predicate
    ///
    /// - Parameters:
    ///   - predicate: The predicate to apply to the objects
    ///   - isChronological: The sort order of the objects by startDate
    /// - Returns: An array of glucose samples, in order by startDate
    private func getCachedGlucoseObjects(matching predicate: NSPredicate? = nil, isChronological: Bool = true) -> [StoredGlucoseSample] {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))
        var samples: [StoredGlucoseSample] = []

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: isChronological)]

            do {
                let objects = try self.cacheStore.managedObjectContext.fetch(request)
                samples = objects.map { StoredGlucoseSample(managedObject: $0) }
            } catch let error {
                self.log.error("Error fetching CachedGlucoseSamples: %@", String(describing: error))
            }
        }

        return samples
    }

    private func updateLatestGlucose() {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
            request.fetchLimit = 1

            do {
                let objects = try self.cacheStore.managedObjectContext.fetch(request)

                if let lastObject = objects.first {
                    self.latestGlucose = StoredGlucoseSample(managedObject: lastObject)
                }
            } catch let error {
                self.log.error("Unable to fetch latest glucose object: %@", String(describing: error))
            }
        }
    }
    
    private func deleteCachedObjects(forSampleUUIDs uuids: [UUID], batchSize: Int = 500) -> Result<Int,Error> {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        var deleted = 0

        for batch in uuids.chunked(into: batchSize) {
            let result = self.purgeCachedGlucoseObjects(matching: NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID }))
            switch result {
            case .failure(let error):
                return .failure(error)
            case .success(let count):
                deleted += count
            }
        }

        return .success(deleted)
    }

    private func deleteCachedObject(forSampleUUID uuid: UUID) -> Bool {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        var deleted = false

        cacheStore.managedObjectContext.performAndWait {
            for object in self.cacheStore.managedObjectContext.cachedGlucoseObjectsWithUUID(uuid) {

                self.cacheStore.managedObjectContext.delete(object)
                deleted = true
            }

            if deleted {
                self.cacheStore.save()
            }
        }

        return deleted
    }

    public var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
    }

    private var earliestObservationDate: Date {
        return Date(timeIntervalSinceNow: -observationInterval)
    }

    public func purgeCachedGlucoseObjects(before date: Date, completion: @escaping (Error?) -> Void) {
        dataAccessQueue.async {
            let result = self.purgeCachedGlucoseObjects(matching: NSPredicate(format: "startDate < %@", date as NSDate))
            
            switch result {
            case .failure(let error):
                completion(error)
            case .success:
                self.delegate?.glucoseStoreHasUpdatedGlucoseData(self)
                completion(nil)
            }
        }
    }

    @discardableResult
    private func purgeCachedGlucoseObjects(matching predicate: NSPredicate?) -> GlucoseStoreResult<Int> {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))
        
        var result: GlucoseStoreResult<Int> = .success(0)

        cacheStore.managedObjectContext.performAndWait {
            do {
                let count = try cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)
                self.log.default("Purged %d CachedGlucoseObjects", count)
                result = .success(count)
            } catch let error {
                self.log.error("Unable to purge CachedGlucoseObjects: %{public}@", String(describing: error))
                result = .failure(error)
            }
        }
        return result
    }
}


// MARK: - Math
extension GlucoseStore {
    /**
     Calculates the momentum effect for recent glucose values

     The duration of effect data returned is determined by the `momentumDataInterval`, and the delta between data points is 5 minutes.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - Parameters:
        - completion: A closure called once the calculation has completed. The closure takes two arguments:
        - effects: The calculated effect values, or an empty array if the glucose data isn't suitable for momentum calculation.
     */
    public func getRecentMomentumEffect(_ completion: @escaping (_ effects: [GlucoseEffect]) -> Void) {
        getCachedGlucoseSamples(start: Date(timeIntervalSinceNow: -momentumDataInterval)) { (samples) in
            let effects = samples.linearMomentumEffect(
                duration: self.momentumDataInterval,
                delta: TimeInterval(minutes: 5)
            )
            completion(effects)
        }
    }

    /// Calculates the a change in glucose values between the specified date interval.
    /// 
    /// Values within the date interval must not include a calibration, and the returned change 
    /// values will be from the same source.
    ///
    /// - Parameters:
    ///   - start: The earliest date to include. The earliest supported date when the Health database is unavailable is determined by `cacheLength`.
    ///   - end: The latest date to include
    ///   - completion: A closure called once the calculation has completed
    ///   - change: A tuple of the first and last glucose values describing the change, if computable.
    public func getGlucoseChange(start: Date, end: Date? = nil, completion: @escaping (_ change: (GlucoseValue, GlucoseValue)?) -> Void) {
        getCachedGlucoseSamples(start: start, end: end) { (samples) in
            let change: (GlucoseValue, GlucoseValue)?

            if let provenanceIdentifier = samples.last?.provenanceIdentifier {
                // Enforce a single source
                let samples = samples.filterAfterCalibration().filter { $0.provenanceIdentifier == provenanceIdentifier }

                if samples.count > 1,
                    let first = samples.first,
                    let last = samples.last,
                    first.startDate < last.startDate
                {
                    change = (first, last)
                } else {
                    change = nil
                }
            } else {
                change = nil
            }

            completion(change)
        }
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose that counteract the specified effects.
    ///
    /// - Parameters:
    ///   - start: The earliest date of glucose values to include
    ///   - end: The latest date of glucose values to include, if provided
    ///   - effects: Glucose effects to be countered, in chronological order
    ///   - completion: A closure called once the values have been retrieved
    ///   - effects: An array of velocities describing the change in glucose samples compared to the specified effects
    public func getCounteractionEffects(start: Date, end: Date? = nil, to effects: [GlucoseEffect], _ completion: @escaping (_ effects: [GlucoseEffectVelocity]) -> Void) {
        getCachedGlucoseSamples(start: start, end: end) { (samples) in
            completion(self.counteractionEffects(for: samples, to: effects))
        }
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose that counteract the specified effects.
    ///
    /// - Parameter:
    ///   - samples: The observed timeline of samples
    ///   - effects: An array of velocities describing the change in glucose samples compared to the specified effects
    public func counteractionEffects<Sample: GlucoseSampleValue>(for samples: [Sample], to effects: [GlucoseEffect]) -> [GlucoseEffectVelocity] {
        samples.counteractionEffects(to: effects)
    }
}

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
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredGlucoseSample]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, queryResult))
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

extension GlucoseStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        dataAccessQueue.async {
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

            for sample in self.getCachedGlucoseObjects() {
                report.append(String(describing: sample))
            }

            report.append("")

            completionHandler(report.joined(separator: "\n"))
        }
    }
}

extension NSManagedObjectContext {
    fileprivate func cachedGlucoseObjectsWithUUID(_ uuid: UUID, fetchLimit: Int? = nil) -> [CachedGlucoseObject] {
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "uuid", ascending: true)]

        return (try? fetch(request)) ?? []
    }

    fileprivate func cachedGlucoseObjectsWithSyncIdentifier(_ syncIdentifier: String, fetchLimit: Int? = nil) -> [CachedGlucoseObject] {
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "syncIdentifier == %@", syncIdentifier)

        return (try? fetch(request)) ?? []
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension GlucoseStore {
    public func addGlucoseSamples(samples: [StoredGlucoseSample], completion: @escaping (Error?) -> Void) {
        guard !samples.isEmpty else {
            completion(nil)
            return
        }

        dataAccessQueue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                for sample in samples {
                    let object = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: sample)
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
