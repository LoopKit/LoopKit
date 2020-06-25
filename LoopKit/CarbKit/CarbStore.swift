//
//  CarbStore.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import HealthKit
import os.log


public enum CarbStoreResult<T> {
    case success(T)
    case failure(CarbStore.CarbStoreError)
}

public enum CarbAbsorptionModel {
    case linear
    case nonlinear
    case adaptiveRateNonlinear
}

public protocol CarbStoreDelegate: class {

    /**
     Informs the delegate that the carb store has updated carb data.

     - Parameter carbStore: The carb store that has updated carb data.
     */
    func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore)

    /**
     Informs the delegate that an internal error occurred.

     - parameter carbStore: The carb store
     - parameter error:     The error describing the issue
     */
    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError)

}

/**
 Manages storage, retrieval, and calculation of carbohydrate data.

 There are two tiers of storage:

 * Persistant cache, stored in Core Data, used to ensure access if the app is suspended and re-launched while the Health database
   is protected and to provide data for upload to remote data services. Backfilled from HealthKit data up to observation interval.
 ```
 0       [max(cacheLength, observationInterval, defaultAbsorptionTimes.slow * 2)]
 |––––––––––––|
 ```
 * HealthKit data, managed by the current application and persisted indefinitely
 ```
 0
 |––––––––––––––––––--->
 ```
 */
public final class CarbStore: HealthKitSampleStore {
    
    /// Notification posted when carb entries were changed, either via add/replace/delete methods or from HealthKit
    public static let carbEntriesDidUpdate = NSNotification.Name(rawValue: "com.loudnate.CarbKit.carbEntriesDidUpdate")

    public typealias DefaultAbsorptionTimes = (fast: TimeInterval, medium: TimeInterval, slow: TimeInterval)

    public static let defaultAbsorptionTimes: DefaultAbsorptionTimes = (fast: TimeInterval(hours: 2), medium: TimeInterval(hours: 3), slow: TimeInterval(hours: 4))

    /// The default longest expected absorption time interval for carbohydrates: 8 hours.
    public static var defaultMaximumAbsorptionTimeInterval: TimeInterval {
        return defaultAbsorptionTimes.slow * 2
    }

    public enum CarbStoreError: Error {
        // The store isn't correctly configured for the requested operation
        case notConfigured
        // The health store request returned an error
        case healthStoreError(Error)
        // The requested sample can't be modified by this store
        case unauthorized
        // No data was found to match the specified request
        case noData
    }

    private let carbType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)!

    /// The preferred unit. iOS currently only supports grams for dietary carbohydrates.
    public override var preferredUnit: HKUnit! {
        return super.preferredUnit
    }

    /// A history of recently applied schedule overrides.
    private let overrideHistory: TemporaryScheduleOverrideHistory?

    /// Carbohydrate-to-insulin ratio
    public var carbRatioSchedule: CarbRatioSchedule? {
        get {
            return lockedCarbRatioSchedule.value
        }
        set {
            lockedCarbRatioSchedule.value = newValue
        }
    }
    private let lockedCarbRatioSchedule: Locked<CarbRatioSchedule?>

    /// The carb ratio schedule, applying recent overrides relative to the current moment in time.
    public var carbRatioScheduleApplyingOverrideHistory: CarbRatioSchedule? {
        if let carbRatioSchedule = carbRatioSchedule {
            return overrideHistory?.resolvingRecentCarbRatioSchedule(carbRatioSchedule)
        } else {
            return nil
        }
    }

    /// A trio of default carbohydrate absorption times. Defaults to 2, 3, and 4 hours.
    public let defaultAbsorptionTimes: DefaultAbsorptionTimes

    /// Insulin-to-glucose sensitivity
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        get {
            return lockedInsulinSensitivitySchedule.value
        }
        set {
            lockedInsulinSensitivitySchedule.value = newValue
        }
    }
    private let lockedInsulinSensitivitySchedule:  Locked<InsulinSensitivitySchedule?>

    /// The insulin sensitivity schedule, applying recent overrides relative to the current moment in time.
    public var insulinSensitivityScheduleApplyingOverrideHistory: InsulinSensitivitySchedule? {
        if let insulinSensitivitySchedule = insulinSensitivitySchedule {
            return overrideHistory?.resolvingRecentInsulinSensitivitySchedule(insulinSensitivitySchedule)
        } else {
            return nil
        }
    }

    /// The computed carbohydrate sensitivity schedule based on the insulin sensitivity and carb ratio schedules.
    public var carbSensitivitySchedule: CarbSensitivitySchedule? {
        guard let insulinSensitivitySchedule = insulinSensitivitySchedule, let carbRatioSchedule = carbRatioSchedule else {
            return nil
        }
        return .carbSensitivitySchedule(insulinSensitivitySchedule: insulinSensitivitySchedule, carbRatioSchedule: carbRatioSchedule)
    }

    /// The expected delay in the appearance of glucose effects, accounting for both digestion and sensor lag
    public let delay: TimeInterval

    /// The interval between effect values to use for the calculated timelines.
    public let delta: TimeInterval

    /// The factor by which the entered absorption time can be extended to accomodate slower-than-expected absorption
    public let absorptionTimeOverrun: Double
    
    /// Carb absorption model
    public let carbAbsorptionModel: CarbAbsorptionModel

    /// The interval of carb data to keep in cache
    public let cacheLength: TimeInterval

    /// The interval to observe HealthKit data to populate the cache
    public let observationInterval: TimeInterval

    private let cacheStore: PersistenceController

    /// The sync version used for new samples written to HealthKit
    /// Choose a lower or higher sync version if the same sample might be written twice (e.g. from an extension and from an app) for deterministic conflict resolution
    public let syncVersion: Int

    public weak var delegate: CarbStoreDelegate?

    private let queue = DispatchQueue(label: "com.loudnate.CarbKit.dataAccessQueue", qos: .utility)

    private let log = OSLog(category: "CarbStore")
    
    var settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: 1.5, adaptiveAbsorptionRateEnabled: false)


    /**
     Initializes a new instance of the store.

     - returns: A new instance of the store
     */
    public init(
        healthStore: HKHealthStore,
        observeHealthKitForCurrentAppOnly: Bool,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = defaultAbsorptionTimes.slow * 2,
        defaultAbsorptionTimes: DefaultAbsorptionTimes = defaultAbsorptionTimes,
        observationInterval: TimeInterval? = nil,
        carbRatioSchedule: CarbRatioSchedule? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
        overrideHistory: TemporaryScheduleOverrideHistory? = nil,
        syncVersion: Int = 1,
        absorptionTimeOverrun: Double = 1.5,
        calculationDelta: TimeInterval = 5 /* minutes */ * 60,
        effectDelay: TimeInterval = 10 /* minutes */ * 60,
        carbAbsorptionModel: CarbAbsorptionModel = .nonlinear
    ) {
        self.cacheStore = cacheStore
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
        self.lockedCarbRatioSchedule = Locked(carbRatioSchedule)
        self.lockedInsulinSensitivitySchedule = Locked(insulinSensitivitySchedule)
        self.overrideHistory = overrideHistory
        self.syncVersion = syncVersion
        self.absorptionTimeOverrun = absorptionTimeOverrun
        self.delta = calculationDelta
        self.delay = effectDelay
        self.cacheLength = max(cacheLength, observationInterval ?? 0, defaultAbsorptionTimes.slow * 2)
        self.observationInterval = max(observationInterval ?? 0, defaultAbsorptionTimes.slow * 2)
        self.carbAbsorptionModel = carbAbsorptionModel

        super.init(healthStore: healthStore, observeHealthKitForCurrentAppOnly: observeHealthKitForCurrentAppOnly, type: carbType, observationStart: Date(timeIntervalSinceNow: -self.observationInterval), observationEnabled: observationEnabled)

        cacheStore.onReady { (error) in
            guard error == nil else { return }

            // Migrate modifiedCarbEntries and deletedCarbEntryIDs
            self.cacheStore.managedObjectContext.perform {
                for entry in UserDefaults.standard.modifiedCarbEntries ?? [] {
                    let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: entry)
                }


                for externalID in UserDefaults.standard.deletedCarbEntryIds ?? [] {
                    let object = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                    object.externalID = externalID
                }

                self.cacheStore.save()
            }

            UserDefaults.standard.purgeLegacyCarbEntryKeys()
            
            // Carb model settings based on the selected absorption model
            switch self.carbAbsorptionModel {
            case .linear:
                self.settings = CarbModelSettings(absorptionModel: LinearAbsorption(), initialAbsorptionTimeOverrun: absorptionTimeOverrun, adaptiveAbsorptionRateEnabled: false)
            case .nonlinear:
                self.settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: absorptionTimeOverrun, adaptiveAbsorptionRateEnabled: false)
            case .adaptiveRateNonlinear:
                self.settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: 1.0, adaptiveAbsorptionRateEnabled: true, adaptiveRateStandbyIntervalFraction: 0.2)
            }

            // TODO: Consider resetting uploadState.uploading
        }
    }

    // MARK: - HealthKitSampleStore

    public override func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], error: Error?) {
        if let error = error {
            self.delegate?.carbStore(self, didError: .healthStoreError(error))
            return
        }

        queue.async {
            var notificationRequired = false

            // Append the new samples
            if let samples = added as? [HKQuantitySample] {
                for sample in samples {
                    if self.addCachedObject(for: sample) {
                        self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                        notificationRequired = true
                    }
                }
            }

            // Remove deleted samples
            for sample in deleted {
                if self.deleteCachedObject(for: sample) {
                    self.log.debug("Deleted sample %@ from cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                    notificationRequired = true
                }
            }

            // Notify listeners only if a meaningful change was made
            if notificationRequired {
                self.cacheStore.save()
                self.notifyDelegateOfUpdatedCarbData()

                NotificationCenter.default.post(name: CarbStore.carbEntriesDidUpdate, object: self, userInfo: [CarbStore.notificationUpdateSourceKey: UpdateSource.queriedByHealthKit.rawValue])
            }
        }
    }
}


// MARK: - Fetching
extension CarbStore {
    /// Fetches samples from HealthKit
    ///
    /// - Parameters:
    ///   - start: The earliest date of samples to retrieve
    ///   - end: The latest date of samples to retrieve, if provided
    ///   - completion: A closure called once the samples have been retrieved
    ///   - result: An array of samples, in chronological order by startDate
    private func getCarbSamples(start: Date, end: Date? = nil, completion: @escaping (_ result: CarbStoreResult<[StoredCarbEntry]>) -> Void) {
        let predicate = HKQuery.predicateForSamples(observeHealthKitForCurrentAppOnly: observeHealthKitForCurrentAppOnly, withStart: start, end: end)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(sampleType: carbType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { (query, samples, error) in
            if let error = error {
                completion(.failure(.healthStoreError(error)))
            } else {
                completion(.success((samples as? [HKQuantitySample] ?? []).map { StoredCarbEntry(sample: $0) }))
            }
        }

        healthStore.execute(query)
    }

    /// Fetches samples from HealthKit, if available, or returns from cache.
    ///
    /// - Parameters:
    ///   - start: The earliest date of samples to retrieve
    ///   - end: The latest date of samples to retrieve, if provided
    ///   - completion: A closure called once the samples have been retrieved
    ///   - samples: An array of samples, in chronological order by startDate
    public func getCachedCarbSamples(start: Date, end: Date? = nil, completion: @escaping (_ samples: [StoredCarbEntry]) -> Void) {
        #if os(iOS)
        // If we're within our observation duration, skip the HealthKit query
        guard start <= earliestObservationDate else {
            self.queue.async {
                completion(self.getCachedCarbEntries().filterDateRange(start, end))
            }
            return
        }
        #endif

        getCarbSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                completion(samples)
            case .failure:
                self.queue.async {
                    completion(self.getCachedCarbEntries().filterDateRange(start, end))
                }
            }
        }
    }

    /// Retrieves carb entries from HealthKit within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure calld once the values have been retrieved
    ///   - result: An array of carb entries, in chronological order by startDate
    public func getCarbEntries(start: Date, end: Date? = nil, completion: @escaping (_ result: CarbStoreResult<[StoredCarbEntry]>) -> Void) {
        getCarbSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                completion(.success(samples))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Retrieves carb entries from HealthKit within the specified date range and interprets their
    /// absorption status based on the provided glucose effect
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    ///   - completion: A closure calld once the values have been retrieved
    ///   - result: An array of carb entries, in chronological order by startDate
    public func getCarbStatus(
        start: Date,
        end: Date? = nil,
        effectVelocities: [GlucoseEffectVelocity]? = nil,
        completion: @escaping (_ result: CarbStoreResult<[CarbStatus<StoredCarbEntry>]>) -> Void
    ) {
        getCarbSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                let status = samples.map(
                    to: effectVelocities ?? [],
                    carbRatio: self.carbRatioScheduleApplyingOverrideHistory,
                    insulinSensitivity: self.insulinSensitivityScheduleApplyingOverrideHistory,
                    absorptionTimeOverrun: self.absorptionTimeOverrun,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay,
                    initialAbsorptionTimeOverrun: self.settings.initialAbsorptionTimeOverrun,
                    absorptionModel: self.settings.absorptionModel,
                    adaptiveAbsorptionRateEnabled: self.settings.adaptiveAbsorptionRateEnabled,
                    adaptiveRateStandbyIntervalFraction: self.settings.adaptiveRateStandbyIntervalFraction
                )

                completion(.success(status))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}


// MARK: - Modification
extension CarbStore {
    public func addCarbEntry(_ entry: NewCarbEntry, completion: @escaping (_ result: CarbStoreResult<StoredCarbEntry>) -> Void) {
        let sample = entry.createSample(from: nil, syncVersion: syncVersion)
        let stored = StoredCarbEntry(sample: sample, createdByCurrentApp: true)

        healthStore.save(sample) { (completed, error) -> Void in
            self.queue.async {
                if completed {
                    self.addCachedObject(for: stored)
                    completion(.success(stored))
                    NotificationCenter.default.post(name: CarbStore.carbEntriesDidUpdate, object: self, userInfo: [CarbStore.notificationUpdateSourceKey: UpdateSource.changedInApp.rawValue])
                    self.notifyDelegateOfUpdatedCarbData()
                } else if let error = error {
                    self.log.error("Error saving entry %@: %@", sample.uuid.uuidString, String(describing: error))
                    completion(.failure(.healthStoreError(error)))
                } else {
                    assertionFailure()
                }
            }
        }
    }

    public func replaceCarbEntry(_ oldEntry: StoredCarbEntry, withEntry newEntry: NewCarbEntry, completion: @escaping (_ result: CarbStoreResult<StoredCarbEntry>) -> Void) {
        guard oldEntry.createdByCurrentApp else {
            completion(.failure(.unauthorized))
            return
        }

        let sample = newEntry.createSample(from: oldEntry, syncVersion: syncVersion)
        let stored = StoredCarbEntry(sample: sample, createdByCurrentApp: true)

        healthStore.save(sample) { (completed, error) -> Void in
            self.queue.async {
                if completed {
                    self.replaceCachedObject(for: oldEntry, with: stored)
                    completion(.success(stored))
                    NotificationCenter.default.post(name: CarbStore.carbEntriesDidUpdate, object: self, userInfo: [CarbStore.notificationUpdateSourceKey: UpdateSource.changedInApp.rawValue])
                    self.notifyDelegateOfUpdatedCarbData()
                } else if let error = error {
                    self.log.error("Error replacing entry %@: %@", oldEntry.sampleUUID.uuidString, String(describing: error))
                    completion(.failure(.healthStoreError(error)))
                } else {
                    assertionFailure()
                }
            }
        }
    }

    public func deleteCarbEntry(_ entry: StoredCarbEntry, completion: @escaping (_ result: CarbStoreResult<Bool>) -> Void) {
        guard entry.createdByCurrentApp else {
            completion(.failure(.unauthorized))
            return
        }

        let predicate = HKQuery.predicateForObject(with: entry.sampleUUID)
        self.healthStore.deleteObjects(of: carbType, predicate: predicate) { (success, count, error) in
            self.queue.async {
                if success {
                    self.deleteCachedObject(for: entry)
                    completion(.success(true))
                    NotificationCenter.default.post(name: CarbStore.carbEntriesDidUpdate, object: self, userInfo: [CarbStore.notificationUpdateSourceKey: UpdateSource.changedInApp.rawValue])
                    self.notifyDelegateOfUpdatedCarbData()
                } else if let error = error {
                    self.log.error("Error deleting entry %@: %@", entry.sampleUUID.uuidString, String(describing: error))
                    completion(.failure(.healthStoreError(error)))
                } else {
                    assertionFailure()
                }
            }
        }
    }
}


extension NSManagedObjectContext {
    fileprivate func cachedCarbObjectsWithUUID(_ uuid: UUID, fetchLimit: Int? = nil) -> [CachedCarbObject] {
        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)

        return (try? fetch(request)) ?? []
    }
}


// MARK: - Cache management
extension CarbStore {
    public var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
    }

    private var earliestObservationDate: Date {
        return Date(timeIntervalSinceNow: -observationInterval)
    }

    @discardableResult
    private func addCachedObject(for sample: HKQuantitySample) -> Bool {
        return addCachedObject(for: StoredCarbEntry(sample: sample))
    }

    @discardableResult
    private func addCachedObject(for entry: StoredCarbEntry) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        var created = false

        cacheStore.managedObjectContext.performAndWait {
            guard self.cacheStore.managedObjectContext.cachedCarbObjectsWithUUID(entry.sampleUUID, fetchLimit: 1).count == 0 else {
                return
            }

            let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
            object.update(from: entry)

            self.cacheStore.save()
            created = true
        }

        return created
    }

    private func replaceCachedObject(for oldEntry: StoredCarbEntry, with newEntry: StoredCarbEntry) {
        dispatchPrecondition(condition: .onQueue(queue))

        cacheStore.managedObjectContext.performAndWait {
            for object in self.cacheStore.managedObjectContext.cachedCarbObjectsWithUUID(oldEntry.sampleUUID) {
                object.update(from: newEntry)
                object.uploadState = .notUploaded
            }

            self.cacheStore.save()
        }
    }

    @discardableResult
    private func deleteCachedObject(for sample: HKDeletedObject) -> Bool {
        return deleteCachedObject(forSampleUUID: sample.uuid)
    }

    @discardableResult
    private func deleteCachedObject(for entry: StoredCarbEntry) -> Bool {
        return deleteCachedObject(forSampleUUID: entry.sampleUUID)
    }

    @discardableResult
    private func deleteCachedObject(forSampleUUID uuid: UUID) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        var deleted = false

        cacheStore.managedObjectContext.performAndWait {
            for object in self.cacheStore.managedObjectContext.cachedCarbObjectsWithUUID(uuid) {
                let deletedObject = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                deletedObject.update(from: object)

                self.cacheStore.managedObjectContext.delete(object)
                deleted = true
            }

            self.cacheStore.save()
        }

        return deleted
    }

    private var cachedDeletedCarbEntries: [DeletedCarbEntry] {
        dispatchPrecondition(condition: .onQueue(queue))
        var entries: [DeletedCarbEntry] = []
        
        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()

            guard let objects = try? self.cacheStore.managedObjectContext.fetch(request) else {
                return
            }
            
            entries = objects.compactMap { DeletedCarbEntry(managedObject: $0) }
        }
        
        return entries
    }

    private func purgeExpiredCachedCarbEntries() {
        dispatchPrecondition(condition: .onQueue(queue))

        cacheStore.managedObjectContext.performAndWait {
            let predicate = NSPredicate(format: "startDate < %@", earliestCacheDate as NSDate)

            do {
                let fetchRequest: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                fetchRequest.predicate = predicate
                let count = try self.cacheStore.managedObjectContext.deleteObjects(matching: fetchRequest)
                self.log.info("Deleted %d CachedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge CachedCarbObjects: %{public}@", String(describing: error))
            }

            do {
                let fetchRequest: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()
                fetchRequest.predicate = predicate
                let count = try self.cacheStore.managedObjectContext.deleteObjects(matching: fetchRequest)
                self.log.info("Deleted %d DeletedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge DeletedCarbObjects: %{public}@", String(describing: error))
            }
        }
    }

    public func purgeCachedCarbEntries(before date: Date, completion: @escaping (Error?) -> Void) {
        queue.async {
            self.purgeCachedCarbObjects(before: date) { error in
                guard error == nil else {
                    completion(error)
                    return
                }
                self.delegate?.carbStoreHasUpdatedCarbData(self)
                completion(nil)
            }
        }
    }

    private func purgeCachedCarbObjects(before date: Date, completion: ((Error?) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(queue))

        let predicate = NSPredicate(format: "startDate < %@", date as NSDate)
        var purgeError: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                let count = try self.cacheStore.managedObjectContext.purgeObjects(of: CachedCarbObject.self, matching: predicate)
                self.log.info("Purged %d CachedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge CachedCarbObjects: %{public}@", String(describing: error))
                purgeError = error
            }

            do {
                let count = try self.cacheStore.managedObjectContext.purgeObjects(of: DeletedCarbObject.self, matching: predicate)
                self.log.info("Purged %d DeletedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge DeletedCarbObjects: %{public}@", String(describing: error))
                purgeError = error
            }
        }

        completion?(purgeError)
    }

    private func notifyDelegateOfUpdatedCarbData() {
        dispatchPrecondition(condition: .onQueue(queue))

        self.purgeExpiredCachedCarbEntries()

        delegate?.carbStoreHasUpdatedCarbData(self)
    }

    // MARK: - Helpers

    /// Fetches carb entries from the cache that match the given predicate
    ///
    /// - Parameter predicate: The predicate to apply to the objects
    /// - Returns: An array of carb entries, in chronological order by startDate
    private func getCachedCarbEntries(matching predicate: NSPredicate? = nil) -> [StoredCarbEntry] {
        dispatchPrecondition(condition: .onQueue(queue))
        var entries: [StoredCarbEntry] = []

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

            guard let objects = try? self.cacheStore.managedObjectContext.fetch(request) else {
                return
            }

            entries = objects.map { StoredCarbEntry(managedObject: $0) }
        }

        return entries
    }
}


// MARK: - Math
extension CarbStore {
    /// The longest expected absorption time interval for carbohydrates. Defaults to 8 hours.
    public var maximumAbsorptionTimeInterval: TimeInterval {
        return defaultAbsorptionTimes.slow * 2
    }

    /// Retrieves the single carbs on-board value occuring just prior or equal to the specified date
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - date: The date of the value to retrieve
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    ///   - completion: A closure called once the value has been retrieved
    ///   - result: The carbs on-board value
    public func carbsOnBoard(at date: Date, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping (_ result: CarbStoreResult<CarbValue>) -> Void) {
        getCarbsOnBoardValues(start: date.addingTimeInterval(-delta), end: date, effectVelocities: effectVelocities) { (values) in
            guard let value = values.closestPrior(to: date) else {
                completion(.failure(.noData))
                return
            }
            completion(.success(value))
        }
    }

    /// Retrieves a timeline of unabsorbed carbohydrates
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    ///   - completion: A closure called once the values have been retrieved
    ///   - values: A timeline of carb values, in chronological order
    public func getCarbsOnBoardValues(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping (_ values: [CarbValue]) -> Void) {
        // To know COB at the requested start date, we need to fetch samples that might still be absorbing
        let foodStart = start.addingTimeInterval(-maximumAbsorptionTimeInterval)
        getCachedCarbSamples(start: foodStart, end: end) { (samples) in
            let carbsOnBoard = self.carbsOnBoard(from: samples, startingAt: start, endingAt: end, effectVelocities: effectVelocities)
            completion(carbsOnBoard)
        }
    }

    /// Computes a timeline of unabsorbed carbohydrates
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    /// - Returns: A timeline of unabsorbed carbohydrates
    public func carbsOnBoard<Sample: CarbEntry>(
        from samples: [Sample],
        startingAt start: Date,
        endingAt end: Date? = nil,
        effectVelocities: [GlucoseEffectVelocity]? = nil
    ) -> [CarbValue] {
        if  let velocities = effectVelocities,
            let carbRatioSchedule = carbRatioScheduleApplyingOverrideHistory,
            let insulinSensitivitySchedule = insulinSensitivityScheduleApplyingOverrideHistory
        {
            return samples.map(
                to: velocities,
                carbRatio: carbRatioSchedule,
                insulinSensitivity: insulinSensitivitySchedule,
                absorptionTimeOverrun: absorptionTimeOverrun,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                delay: delay,
                initialAbsorptionTimeOverrun: settings.initialAbsorptionTimeOverrun,
                absorptionModel: settings.absorptionModel,
                adaptiveAbsorptionRateEnabled: settings.adaptiveAbsorptionRateEnabled,
                adaptiveRateStandbyIntervalFraction: settings.adaptiveRateStandbyIntervalFraction
            ).dynamicCarbsOnBoard(
                from: start,
                to: end,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                absorptionModel: settings.absorptionModel,
                delay: delay,
                delta: delta
            )
        } else {
            return samples.carbsOnBoard(
                from: start,
                to: end,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                absorptionModel: settings.absorptionModel,
                delay: delay,
                delta: delta
            )
        }
    }

    /// Computes the single carbs on-board value occuring just prior or equal to the specified date
    /// - Parameters:
    ///   - date: The date of the value to retrieve
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    /// - Returns: The carbs on-board value
    public func carbsOnBoard<Sample: CarbEntry>(
        from samples: [Sample],
        at date: Date,
        effectVelocities: [GlucoseEffectVelocity]? = nil
    ) throws -> CarbValue {
        let values = carbsOnBoard(from: samples, startingAt: date.addingTimeInterval(-delta), endingAt: date, effectVelocities: effectVelocities)

        guard let value = values.closestPrior(to: date) else {
            throw CarbStoreError.noData
        }

        return value
    }


    /// Retrieves a timeline of effect on blood glucose from carbohydrates
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of effects to retrieve
    ///   - end: The latest date of effects to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    ///   - completion: A closure called once the effects have been retrieved
    ///   - result: An array of effects, in chronological order
    public func getGlucoseEffects(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping(_ result: CarbStoreResult<(samples: [StoredCarbEntry], effects: [GlucoseEffect])>) -> Void) {
        queue.async {
            guard self.carbRatioSchedule != nil, self.insulinSensitivitySchedule != nil else {
                completion(.failure(.notConfigured))
                return
            }

            // To know glucose effects at the requested start date, we need to fetch samples that might still be absorbing
            let foodStart = start.addingTimeInterval(-self.maximumAbsorptionTimeInterval)
            
            self.getCachedCarbSamples(start: foodStart, end: end) { (samples) in
                do {
                    let effects = try self.glucoseEffects(of: samples, startingAt: start, endingAt: end, effectVelocities: effectVelocities)
                    completion(.success((samples: samples, effects: effects)))
                } catch let error as CarbStoreError {
                    completion(.failure(error))
                } catch {
                    fatalError()
                }
            }
        }
    }

    /// Computes a timeline of effects on blood glucose from carbohydrates
    /// - Parameters:
    ///   - start: The earliest date of effects to retrieve
    ///   - end: The latest date of effects to retrieve, if provided
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    public func glucoseEffects<Sample: CarbEntry>(
        of samples: [Sample],
        startingAt start: Date,
        endingAt end: Date? = nil,
        effectVelocities: [GlucoseEffectVelocity]? = nil
    ) throws -> [GlucoseEffect] {
        guard
            let carbRatioSchedule = carbRatioScheduleApplyingOverrideHistory,
            let insulinSensitivitySchedule = insulinSensitivityScheduleApplyingOverrideHistory
        else {
            throw CarbStoreError.notConfigured
        }

        if let effectVelocities = effectVelocities {
            return samples.map(
                to: effectVelocities,
                carbRatio: carbRatioSchedule,
                insulinSensitivity: insulinSensitivitySchedule,
                absorptionTimeOverrun: absorptionTimeOverrun,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                delay: delay,
                initialAbsorptionTimeOverrun: settings.initialAbsorptionTimeOverrun,
                absorptionModel: settings.absorptionModel,
                adaptiveAbsorptionRateEnabled: settings.adaptiveAbsorptionRateEnabled,
                adaptiveRateStandbyIntervalFraction: settings.adaptiveRateStandbyIntervalFraction
            ).dynamicGlucoseEffects(
                from: start,
                to: end,
                carbRatios: carbRatioSchedule,
                insulinSensitivities: insulinSensitivitySchedule,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                absorptionModel: settings.absorptionModel,
                delay: delay,
                delta: delta
            )
        } else {
            return samples.glucoseEffects(
                from: start,
                to: end,
                carbRatios: carbRatioSchedule,
                insulinSensitivities: insulinSensitivitySchedule,
                defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                absorptionModel: settings.absorptionModel,
                delay: delay,
                delta: delta
            )
        }
    }

    /// Retrieves the total number of recorded carbohydrates for the specified period.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of samples to include.
    ///   - completion: A closure called once the value has been retrieved.
    ///   - result: The total carbs recorded and the date of the first sample
    public func getTotalCarbs(since start: Date, completion: @escaping (_ result: CarbStoreResult<CarbValue>) -> Void) {
        getCarbSamples(start: start) { (result) in
            switch result {
            case .success(let samples):
                let total = samples.totalCarbs ?? CarbValue(
                    startDate: start,
                    quantity: HKQuantity(unit: self.preferredUnit, doubleValue: 0)
                )

                completion(.success(total))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}


extension CarbStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        queue.async {
            
            var carbAbsorptionModel: String
            switch self.carbAbsorptionModel {
            case .linear:
                carbAbsorptionModel = "Linear"
            case .nonlinear:
                carbAbsorptionModel = "Nonlinear"
            case .adaptiveRateNonlinear:
                carbAbsorptionModel = "Nonlinear with Adaptive Rate for Remaining Carbs"
            }
            
            var report: [String] = [
                "## CarbStore",
                "",
                "* carbRatioSchedule: \(self.carbRatioSchedule?.debugDescription ?? "")",
                "* carbRatioScheduleApplyingOverrideHistory: \(self.carbRatioScheduleApplyingOverrideHistory?.debugDescription ?? "nil")",
                "* cacheLength: \(self.cacheLength)",
                "* defaultAbsorptionTimes: \(self.defaultAbsorptionTimes)",
                "* observationInterval: \(self.observationInterval)",
                "* insulinSensitivitySchedule: \(self.insulinSensitivitySchedule?.debugDescription ?? "")",
                "* insulinSensitivityScheduleApplyingOverrideHistory: \(self.insulinSensitivityScheduleApplyingOverrideHistory?.debugDescription ?? "nil")",
                "* overrideHistory: \(self.overrideHistory.map(String.init(describing:)) ?? "nil")",
                "* carbSensitivitySchedule: \(self.carbSensitivitySchedule?.debugDescription ?? "nil")",
                "* delay: \(self.delay)",
                "* delta: \(self.delta)",
                "* absorptionTimeOverrun: \(self.absorptionTimeOverrun)",
                "* carbAbsorptionModel: \(carbAbsorptionModel)",
                "* Carb absorption model settings: \(self.settings)",
                super.debugDescription,
                "",
                "cachedCarbEntries: [",
                "\tStoredCarbEntry(sampleUUID, syncIdentifier, syncVersion, startDate, quantity, foodType, absorptionTime, createdByCurrentApp, externalID, isUploaded)"
            ]

            let carbEntries = self.getCachedCarbEntries()

            report.append(carbEntries.map({ (entry) -> String in
                return [
                    "\t",
                    String(describing: entry.sampleUUID),
                    entry.syncIdentifier ?? "",
                    String(describing: entry.syncVersion),
                    String(describing: entry.startDate),
                    String(describing: entry.quantity),
                    entry.foodType ?? "",
                    String(describing: entry.absorptionTime ?? self.defaultAbsorptionTimes.medium),
                    String(describing: entry.createdByCurrentApp),
                    entry.externalID ?? "",
                    String(describing: entry.isUploaded),
                ].joined(separator: ", ")
            }).joined(separator: "\n"))
            report.append("]")
            report.append("")

            report.append("deletedCarbEntries: [")
            report.append("\tDeletedCarbEntry(externalID, isUploaded)")
            for entry in self.cachedDeletedCarbEntries {
                report.append("\t\(String(describing: entry.externalID)), \(entry.isUploaded)")
            }
            report.append("]")
            report.append("")

            completionHandler(report.joined(separator: "\n"))
        }
    }
}

extension CarbStore {
    
    public struct QueryAnchor: RawRepresentable {
        
        public typealias RawValue = [String: Any]
        
        internal var deletedModificationCounter: Int64
        
        internal var storedModificationCounter: Int64
        
        public init() {
            self.deletedModificationCounter = 0
            self.storedModificationCounter = 0
        }
        
        public init?(rawValue: RawValue) {
            guard let deletedModificationCounter = rawValue["deletedModificationCounter"] as? Int64,
                let storedModificationCounter = rawValue["storedModificationCounter"] as? Int64
                else {
                    return nil
            }
            self.deletedModificationCounter = deletedModificationCounter
            self.storedModificationCounter = storedModificationCounter
        }
        
        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["deletedModificationCounter"] = deletedModificationCounter
            rawValue["storedModificationCounter"] = storedModificationCounter
            return rawValue
        }
    }
    
    public enum CarbQueryResult {
        case success(QueryAnchor, [DeletedCarbEntry], [StoredCarbEntry])
        case failure(Error)
    }
    
    public func executeCarbQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (CarbQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryDeletedResult = [DeletedCarbEntry]()
            var queryStoredResult = [StoredCarbEntry]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, queryDeletedResult, queryStoredResult))
                return
            }
            
            self.cacheStore.managedObjectContext.performAndWait {
                let deletedRequest: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()
                
                deletedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.deletedModificationCounter)
                deletedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                deletedRequest.fetchLimit = limit
                
                do {
                    let deleted = try self.cacheStore.managedObjectContext.fetch(deletedRequest)
                    if let modificationCounter = deleted.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.deletedModificationCounter = modificationCounter
                    }
                    queryDeletedResult.append(contentsOf: deleted.compactMap { DeletedCarbEntry(managedObject: $0) })
                } catch let error {
                    queryError = error
                    return
                }
                
                if queryDeletedResult.count >= limit {
                    return
                }
                
                let storedRequest: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                
                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.storedModificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit - queryDeletedResult.count
                
                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.storedModificationCounter = modificationCounter
                    }
                    queryStoredResult.append(contentsOf: stored.compactMap { StoredCarbEntry(managedObject: $0) })
                } catch let error {
                    queryError = error
                    return
                }
            }
            
            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }
            
            completion(.success(queryAnchor, queryDeletedResult, queryStoredResult))
        }
    }
    
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension CarbStore {
    public func addStoredCarbEntries(entries: [StoredCarbEntry], completion: @escaping (Error?) -> Void) {
        guard !entries.isEmpty else {
            completion(nil)
            return
        }

        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                for entry in entries {
                    let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: entry)
                }
                self.cacheStore.save { error = $0 }
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d CachedCarbObjects", entries.count)
            self.delegate?.carbStoreHasUpdatedCarbData(self)
            completion(nil)
        }
    }

    public func addDeletedCarbEntries(entries: [DeletedCarbEntry], completion: @escaping (Error?) -> Void) {
        guard !entries.isEmpty else {
            completion(nil)
            return
        }

        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                for entry in entries {
                    let object = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: entry)
                }
                self.cacheStore.save { error = $0 }
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d DeletedCarbObjects", entries.count)
            self.delegate?.carbStoreHasUpdatedCarbData(self)
            completion(nil)
        }
    }
}
