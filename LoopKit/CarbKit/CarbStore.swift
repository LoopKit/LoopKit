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

    /// Informs the delegate that an internal error occurred
    ///
    /// - parameter carbStore: The carb store
    /// - parameter error:     The error describing the issue
    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError)
}

public protocol CarbStoreSyncDelegate: class {

    /// Asks the delegate to upload recently-added carb entries not yet marked as uploaded.
    ///
    /// The completion handler must be called in all circumstances with each entry passed to the delegate
    ///
    /// - parameter carbStore:  The store instance
    /// - parameter entries:    The carb entries
    /// - parameter completion: The closure to execute when the upload attempt(s) have completed. The closure takes a single argument of an array of entries. Populate `externalID` and set `isUploaded` for each entry that was uploaded, or pass back the entry unmodified for each entry that failed to upload.
    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void)

    /// Asks the delegate to delete carb entries that were previously uploaded.
    ///
    /// The completion handler must be called in all circumstances with each entry passed to the delegate
    ///
    /// - parameter carbStore:  The store instance
    /// - parameter entries:    The deleted entries
    /// - parameter completion: The closure to execute when the deletion attempt(s) have finished. The closure takes a single argument of an array of entries. Set `isUploaded` to true for each entry that was uploaded, or pass back the entry unmodified for each entry that failed to upload.
    func carbStore(_ carbStore: CarbStore, hasDeletedEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void)
}

/**
 Manages storage, retrieval, and calculation of carbohydrate data.

 There are two tiers of storage:

 * Short-term persistant cache, stored in Core Data, used to ensure access if the app is suspended and re-launched while the Health database is protected
 ```
 0       [cacheLength]
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

    public let cacheStore: PersistenceController

    /// The sync version used for new samples written to HealthKit
    /// Choose a lower or higher sync version if the same sample might be written twice (e.g. from an extension and from an app) for deterministic conflict resolution
    public let syncVersion: Int

    public weak var delegate: CarbStoreDelegate?

    public weak var syncDelegate: CarbStoreSyncDelegate?

    private let queue = DispatchQueue(label: "com.loudnate.CarbKit.dataAccessQueue", qos: .utility)

    private let log = OSLog(category: "CarbStore")
    
    var settings = CarbModelSettings(absorptionModel: LinearAbsorption(), initialAbsorptionTimeOverrun: 1.5, adaptiveAbsorptionRateEnabled: false)

    /**
     Initializes a new instance of the store.

     - returns: A new instance of the store
     */
    public init(
        healthStore: HKHealthStore,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = defaultAbsorptionTimes.slow * 2,
        defaultAbsorptionTimes: DefaultAbsorptionTimes = defaultAbsorptionTimes,
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
        self.cacheLength = max(cacheLength, defaultAbsorptionTimes.slow * 2)
        self.carbAbsorptionModel = carbAbsorptionModel

        super.init(healthStore: healthStore, type: carbType, observationStart: Date(timeIntervalSinceNow: -cacheLength), observationEnabled: observationEnabled)

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
                self.syncExternalDB()

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
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
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
        // If we're within our cache duration, skip the HealthKit query
        guard start <= earliestCacheDate else {
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
                    self.syncExternalDB()
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
                    self.syncExternalDB()
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
                    self.syncExternalDB()
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

    fileprivate func deleteObjects<T>(matching fetchRequest: NSFetchRequest<T>) throws -> Int where T: NSManagedObject {
        let objects = try fetch(fetchRequest)

        for object in objects {
            delete(object)
        }

        if hasChanges {
            try save()
        }

        return objects.count
    }
}


// MARK: - Cache management
extension CarbStore {
    private var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
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
                if let externalID = object.externalID {
                    let deletedObject = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                    deletedObject.externalID = externalID
                }

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

    private func purgeCachedCarbEntries() {
        dispatchPrecondition(condition: .onQueue(queue))

        cacheStore.managedObjectContext.performAndWait {
            let predicate = NSPredicate(format: "startDate < %@", earliestCacheDate as NSDate)

            do {
                let fetchRequest: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                fetchRequest.predicate = predicate
                let count = try self.cacheStore.managedObjectContext.deleteObjects(matching: fetchRequest)
                self.log.info("Deleted %d CachedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge CachedCarbObjects: %@", String(describing: error))
            }

            do {
                let fetchRequest: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()
                fetchRequest.predicate = predicate
                let count = try self.cacheStore.managedObjectContext.deleteObjects(matching: fetchRequest)
                self.log.info("Deleted %d DeletedCarbObjects", count)
            } catch let error {
                self.log.error("Unable to purge DeletedCarbObjects: %@", String(describing: error))
            }
        }
    }

    private func syncExternalDB() {
        dispatchPrecondition(condition: .onQueue(queue))

        self.purgeCachedCarbEntries()

        guard let syncDelegate = self.syncDelegate else {
            return
        }

        var entriesToUpload: [StoredCarbEntry] = []
        var entriesToDelete: [DeletedCarbEntry] = []

        cacheStore.managedObjectContext.performAndWait {
            let notUploaded = NSPredicate(format: "uploadState == %d", UploadState.notUploaded.rawValue)

            let cachedRequest: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
            cachedRequest.predicate = notUploaded

            if let objectsToUpload = try? self.cacheStore.managedObjectContext.fetch(cachedRequest) {
                entriesToUpload = objectsToUpload.map { StoredCarbEntry(managedObject: $0) }
                objectsToUpload.forEach { $0.uploadState = .uploading }
            }

            let deletedRequest: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()
            deletedRequest.predicate = notUploaded

            if let objectsToDelete = try? self.cacheStore.managedObjectContext.fetch(deletedRequest) {
                entriesToDelete = objectsToDelete.compactMap { DeletedCarbEntry(managedObject: $0) }
                objectsToDelete.forEach { $0.uploadState = .uploading }
            }

            self.cacheStore.save()
        }

        if entriesToUpload.count > 0 {
            syncDelegate.carbStore(self, hasEntriesNeedingUpload: entriesToUpload) { (entries) in
                self.cacheStore.managedObjectContext.perform {
                    var hasMissingObjects = false

                    for entry in entries {
                        let objects = self.cacheStore.managedObjectContext.cachedCarbObjectsWithUUID(entry.sampleUUID)
                        for object in objects {
                            object.externalID = entry.externalID
                            object.uploadState = entry.isUploaded ? .uploaded : .notUploaded
                        }

                        // If our delegate sent back uploaded entries we no longer know about,
                        // consider them needing deletion.
                        if  objects.count == 0,
                            entry.isUploaded,
                            entry.startDate > self.earliestCacheDate,
                            let externalID = entry.externalID
                        {
                            self.log.info("Uploaded entry %@ not found in cache", entry.sampleUUID.uuidString)
                            let deleted = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                            deleted.externalID = externalID
                            hasMissingObjects = true
                        }
                    }

                    self.cacheStore.save()

                    if hasMissingObjects {
                        self.queue.async {
                            self.syncExternalDB()
                        }
                    }
                }
            }
        }

        if entriesToDelete.count > 0 {
            syncDelegate.carbStore(self, hasDeletedEntries: entriesToDelete) { (entries) in
                self.cacheStore.managedObjectContext.perform {
                    for entry in entries {
                        let request: NSFetchRequest<DeletedCarbObject> = DeletedCarbObject.fetchRequest()
                        request.predicate = NSPredicate(format: "externalID == %@", entry.externalID)

                        if let objects = try? self.cacheStore.managedObjectContext.fetch(request) {
                            for object in objects {
                                if entry.isUploaded {
                                    self.cacheStore.managedObjectContext.delete(object)
                                } else {
                                    object.uploadState = .notUploaded
                                }
                            }
                        }
                    }

                    self.cacheStore.save()
                }
            }
        }
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
            let carbsOnBoard: [CarbValue]

            if let velocities = effectVelocities, let carbRatioSchedule = self.carbRatioScheduleApplyingOverrideHistory, let insulinSensitivitySchedule = self.insulinSensitivityScheduleApplyingOverrideHistory {
                carbsOnBoard = samples.map(
                    to: velocities,
                    carbRatio: carbRatioSchedule,
                    insulinSensitivity: insulinSensitivitySchedule,
                    absorptionTimeOverrun: self.absorptionTimeOverrun,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay,
                    initialAbsorptionTimeOverrun: self.settings.initialAbsorptionTimeOverrun,
                    absorptionModel: self.settings.absorptionModel,
                    adaptiveAbsorptionRateEnabled: self.settings.adaptiveAbsorptionRateEnabled,
                    adaptiveRateStandbyIntervalFraction: self.settings.adaptiveRateStandbyIntervalFraction
                ).dynamicCarbsOnBoard(
                    from: start,
                    to: end,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    absorptionModel: self.settings.absorptionModel,
                    delay: self.delay,
                    delta: self.delta
                )
            } else {
                carbsOnBoard = samples.carbsOnBoard(
                    from: start,
                    to: end,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    absorptionModel: self.settings.absorptionModel,
                    delay: self.delay,
                    delta: self.delta
                )
            }

            completion(carbsOnBoard)
        }
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
    public func getGlucoseEffects(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping(_ result: CarbStoreResult<[GlucoseEffect]>) -> Void) {
        queue.async {
            guard let carbRatioSchedule = self.carbRatioScheduleApplyingOverrideHistory, let insulinSensitivitySchedule = self.insulinSensitivityScheduleApplyingOverrideHistory else {
                completion(.failure(.notConfigured))
                return
            }

            // To know glucose effects at the requested start date, we need to fetch samples that might still be absorbing
            let foodStart = start.addingTimeInterval(-self.maximumAbsorptionTimeInterval)
            let defaultAbsorptionTimes = self.defaultAbsorptionTimes
            let absorptionTimeOverrun = self.absorptionTimeOverrun
            let delay = self.delay
            let delta = self.delta
            
            self.getCachedCarbSamples(start: foodStart, end: end) { (samples) in
                let effects: [GlucoseEffect]

                if let effectVelocities = effectVelocities {
                    effects = samples.map(
                        to: effectVelocities,
                        carbRatio: carbRatioSchedule,
                        insulinSensitivity: insulinSensitivitySchedule,
                        absorptionTimeOverrun: absorptionTimeOverrun,
                        defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                        delay: delay,
                        initialAbsorptionTimeOverrun: self.settings.initialAbsorptionTimeOverrun,
                        absorptionModel: self.settings.absorptionModel,
                        adaptiveAbsorptionRateEnabled: self.settings.adaptiveAbsorptionRateEnabled,
                        adaptiveRateStandbyIntervalFraction: self.settings.adaptiveRateStandbyIntervalFraction
                    ).dynamicGlucoseEffects(
                        from: start,
                        to: end,
                        carbRatios: carbRatioSchedule,
                        insulinSensitivities: insulinSensitivitySchedule,
                        defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                        absorptionModel: self.settings.absorptionModel,
                        delay: delay,
                        delta: delta
                    )
                } else {
                    effects = samples.glucoseEffects(
                        from: start,
                        to: end,
                        carbRatios: carbRatioSchedule,
                        insulinSensitivities: insulinSensitivitySchedule,
                        defaultAbsorptionTime: defaultAbsorptionTimes.medium,
                        absorptionModel: self.settings.absorptionModel,
                        delay: delay,
                        delta: delta
                    )
                }

                completion(.success(effects))
            }
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
            case .linear: carbAbsorptionModel = "Linear"
            case .nonlinear: carbAbsorptionModel = "Nonlinear"
            case .adaptiveRateNonlinear: carbAbsorptionModel = "Nonlinear with Adaptive Rate for Remaining Carbs"
            }
            
            var report: [String] = [
                "## CarbStore",
                "",
                "* carbRatioSchedule: \(self.carbRatioSchedule?.debugDescription ?? "")",
                "* carbRatioScheduleApplyingOverrideHistory: \(self.carbRatioScheduleApplyingOverrideHistory?.debugDescription ?? "nil")",
                "* defaultAbsorptionTimes: \(self.defaultAbsorptionTimes)",
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
                report.append("\t\(entry.externalID), \(entry.isUploaded)")
            }
            report.append("]")
            report.append("")

            completionHandler(report.joined(separator: "\n"))
        }
    }
}
