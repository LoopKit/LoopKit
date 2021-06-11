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

public protocol CarbStoreDelegate: AnyObject {

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
    public static let carbEntriesDidChange = NSNotification.Name(rawValue: "com.loopkit.CarbStore.carbEntriesDidChange")

    public typealias DefaultAbsorptionTimes = (fast: TimeInterval, medium: TimeInterval, slow: TimeInterval)

    public enum CarbStoreError: Error {
        // The store isn't correctly configured for the requested operation
        case notConfigured
        // The health store request returned an error
        case healthStoreError(Error)
        // The core data request returned an error
        case coreDataError(Error)
        // The requested sample can't be modified by this store
        case unauthorized
        // No data was found to match the specified request
        case noData

        init?(error: PersistenceController.PersistenceControllerError?) {
            guard let error = error, case .coreDataError(let coreDataError) = error else {
                return nil
            }
            self = .coreDataError(coreDataError as Error)
        }
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

    private let queue = DispatchQueue(label: "com.loopkit.CarbStore.queue", qos: .utility)

    private let log = OSLog(category: "CarbStore")
    
    static let healthKitQueryAnchorMetadataKey = "com.loopkit.CarbStore.hkQueryAnchor"
    
    var settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: 1.5, adaptiveAbsorptionRateEnabled: false)

    private let provenanceIdentifier: String

    /**
     Initializes a new instance of the store.

     - returns: A new instance of the store
     */
    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        cacheStore: PersistenceController,
        cacheLength: TimeInterval,
        defaultAbsorptionTimes: DefaultAbsorptionTimes,
        observationInterval: TimeInterval,
        carbRatioSchedule: CarbRatioSchedule? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
        overrideHistory: TemporaryScheduleOverrideHistory? = nil,
        syncVersion: Int = 1,
        absorptionTimeOverrun: Double = 1.5,
        calculationDelta: TimeInterval = 5 /* minutes */ * 60,
        effectDelay: TimeInterval = 10 /* minutes */ * 60,
        carbAbsorptionModel: CarbAbsorptionModel = .nonlinear,
        provenanceIdentifier: String
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
        self.cacheLength = cacheLength
        self.observationInterval = observationInterval
        self.carbAbsorptionModel = carbAbsorptionModel
        self.provenanceIdentifier = provenanceIdentifier
        
        let observationEnabled = observationInterval > 0

        super.init(healthStore: healthStore,
                   observeHealthKitSamplesFromCurrentApp: false,
                   observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
                   type: carbType,
                   observationStart: Date(timeIntervalSinceNow: -self.observationInterval),
                   observationEnabled: observationEnabled)

        // Carb model settings based on the selected absorption model
        switch self.carbAbsorptionModel {
        case .linear:
            self.settings = CarbModelSettings(absorptionModel: LinearAbsorption(), initialAbsorptionTimeOverrun: absorptionTimeOverrun, adaptiveAbsorptionRateEnabled: false)
        case .nonlinear:
            self.settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: absorptionTimeOverrun, adaptiveAbsorptionRateEnabled: false)
        case .adaptiveRateNonlinear:
            self.settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: 1.0, adaptiveAbsorptionRateEnabled: true, adaptiveRateStandbyIntervalFraction: 0.2)
        }

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            guard error == nil else {
                semaphore.signal()
                return
            }
            
            cacheStore.fetchAnchor(key: CarbStore.healthKitQueryAnchorMetadataKey) { (anchor) in
                self.queue.async {
                    self.queryAnchor = anchor
            
                    self.migrateLegacyCarbEntryKeys()
                    
                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
    }

    // Migrate modifiedCarbEntries and deletedCarbEntryIDs
    private func migrateLegacyCarbEntryKeys() {
        cacheStore.managedObjectContext.performAndWait {
            var changed = false

            for entry in UserDefaults.standard.modifiedCarbEntries ?? [] {
                let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                object.create(from: entry)
                changed = true
            }

            // Note: We no longer migrate UserDefaults.standard.deletedCarbEntryIds since we don't have a startDate (only
            // external ID) and CachedCarbObject requires a starDate. This only prevents a deleted carb entry that was previously
            // uploaded to Nightscout, but not yet deleted from Nightscout, from being deleted in Nightscout.

            if changed {
                self.cacheStore.save()
            }
        }

        UserDefaults.standard.purgeLegacyCarbEntryKeys()
    }

    // MARK: - HealthKitSampleStore
    
    override func queryAnchorDidChange() {
        cacheStore.storeAnchor(queryAnchor, key: CarbStore.healthKitQueryAnchorMetadataKey)
    }

    override func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], anchor: HKQueryAnchor, completion: @escaping (Bool) -> Void) {
        queue.async {
            guard anchor != self.queryAnchor else {
                self.log.default("Skipping processing results from anchored object query, as anchor was already processed")
                completion(true)
                return
            }

            var changed = false
            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let date = Date()

                    // Add new samples
                    if let samples = added as? [HKQuantitySample] {
                        for sample in samples {
                            if try self.addCarbEntry(for: sample, on: date) {
                                self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                                changed = true
                            } else {
                                self.log.default("Sample %@ from HKAnchoredObjectQuery already present in cache", sample.uuid.uuidString)
                            }
                        }
                    }

                    // Delete deleted samples
                    for sample in deleted {
                        if try self.deleteCarbEntry(for: sample.uuid, on: date) {
                            self.log.debug("Deleted sample %@ from cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                            changed = true
                        }
                    }

                    guard changed else {
                        return
                    }

                    error = CarbStoreError(error: self.cacheStore.save())
                } catch let coreDataError {
                    error = .coreDataError(coreDataError)
                }
            }

            if let error = error {
                self.delegate?.carbStore(self, didError: error)
                completion(false)
                return
            }

            if !changed {
                completion(true)
                return
            }

            self.handleUpdatedCarbData(updateSource: .queriedByHealthKit)
            completion(true)
        }
    }
}

// MARK: - Fetching

extension CarbStore {
    /// Retrieves carb entries within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - result: An array of carb entries, in chronological order by startDate, or error
    public func getCarbEntries(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: CarbStoreResult<[StoredCarbEntry]>) -> Void) {
        queue.async {
            completion(self.getCarbEntries(start: start, end: end))
        }
    }

    /// Retrieves carb entries within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    /// - Returns: An array of carb entries, in chronological order by startDate, or error
    private func getCarbEntries(start: Date? = nil, end: Date? = nil) -> CarbStoreResult<[StoredCarbEntry]> {
        dispatchPrecondition(condition: .onQueue(queue))

        var entries: [StoredCarbEntry] = []
        var error: CarbStoreError?

        cacheStore.managedObjectContext.performAndWait {
            do {
                entries = try self.getActiveCachedCarbObjects(start: start, end: end).map { StoredCarbEntry(managedObject: $0) }
            } catch let coreDataError {
                error = .coreDataError(coreDataError)
            }
        }

        if let error = error {
            return .failure(error)
        }

        return .success(entries)
    }

    /// Retrieves active (not superceded, non-delete operation) cached carb objects within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    /// - Returns: An array of cached carb objects
    private func getActiveCachedCarbObjects(start: Date? = nil, end: Date? = nil) throws -> [CachedCarbObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        var predicates = [NSPredicate(format: "operation != %d", Operation.delete.rawValue),
                          NSPredicate(format: "supercededDate == NIL")]
        if let start = start {
            predicates.append(NSPredicate(format: "startDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate < %@", end as NSDate))
        }

        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
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
        getCarbEntries(start: start, end: end) { (result) in
            switch result {
            case .success(let entries):
                let status = entries.map(
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
        queue.async {
            var storedEntry: StoredCarbEntry?
            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let syncIdentifier = try self.cacheStore.managedObjectContext.generateUniqueSyncIdentifier()

                    let newObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    newObject.create(from: entry,
                                     provenanceIdentifier: self.provenanceIdentifier,
                                     syncIdentifier: syncIdentifier,
                                     syncVersion: self.syncVersion)

                    if let saveError = CarbStoreError(error: self.cacheStore.save()) {
                        error = saveError
                        return
                    }

                    self.saveEntryToHealthKit(newObject)

                    storedEntry = StoredCarbEntry(managedObject: newObject)
                } catch let coreDataError {
                    error = .coreDataError(coreDataError)
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(storedEntry!))

            self.handleUpdatedCarbData(updateSource: .changedInApp)
        }
    }

    public func replaceCarbEntry(_ oldEntry: StoredCarbEntry, withEntry newEntry: NewCarbEntry, completion: @escaping (_ result: CarbStoreResult<StoredCarbEntry>) -> Void) {
        guard oldEntry.createdByCurrentApp else {
            completion(.failure(.unauthorized))
            return
        }

        queue.async {
            var storedEntry: StoredCarbEntry?
            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    guard let oldObject = try self.cacheStore.managedObjectContext.cachedCarbObjectFromStoredCarbEntry(oldEntry) else {
                        error = .noData
                        return
                    }

                    // Use same date for superceding old object and adding new object
                    let date = Date()

                    oldObject.supercededDate = date

                    let newObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    newObject.update(from: newEntry, replacing: oldObject, on: date)

                    if let saveError = CarbStoreError(error: self.cacheStore.save()) {
                        error = saveError
                        return
                    }

                    self.saveEntryToHealthKit(newObject)

                    storedEntry = StoredCarbEntry(managedObject: newObject)
                } catch let coreDataError {
                    error = .coreDataError(coreDataError)
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(storedEntry!))

            self.handleUpdatedCarbData(updateSource: .changedInApp)
        }
    }

    private func saveEntryToHealthKit(_ object: CachedCarbObject) {
        dispatchPrecondition(condition: .onQueue(queue))

        let quantitySample = object.quantitySample
        var error: Error?

        // Save object to HealthKit, log any errors, but do not fail
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.healthStore.save(quantitySample) { (_, healthKitError) in
            error = healthKitError
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        if let error = error {
            self.log.error("Error saving HealthKit object: %@", String(describing: error))
            return
        }

        // Update Core Data with the change, log any errors, but do not fail
        object.uuid = quantitySample.uuid
        if let error = self.cacheStore.save() {
            self.log.error("Error updating CachedCarbObject after saving HealthKit object: %@", String(describing: error))
            object.uuid = nil
        }
    }

    public func deleteCarbEntry(_ oldEntry: StoredCarbEntry, completion: @escaping (_ result: CarbStoreResult<Bool>) -> Void) {
        guard oldEntry.createdByCurrentApp else {
            completion(.failure(.unauthorized))
            return
        }

        queue.async {
            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    guard let oldObject = try self.cacheStore.managedObjectContext.cachedCarbObjectFromStoredCarbEntry(oldEntry) else {
                        error = .noData
                        return
                    }

                    // Use same date for superceding old object and adding new object; also used for userDeletedDate
                    let date = Date()

                    oldObject.supercededDate = date

                    let newObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    newObject.delete(from: oldObject, on: date)

                    if let saveError = CarbStoreError(error: self.cacheStore.save()) {
                        error = saveError
                        return
                    }

                    self.deleteObjectFromHealthKit(newObject)
                } catch let coreDataError {
                    error = .coreDataError(coreDataError)
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(true))

            self.handleUpdatedCarbData(updateSource: .changedInApp)
        }
    }

    private func deleteObjectFromHealthKit(_ object: CachedCarbObject) {
        dispatchPrecondition(condition: .onQueue(queue))

        // If the object does not have a UUID, then it was never saved to HealthKit, so no need to delete
        guard object.uuid != nil else {
            return
        }

        var error: Error?

        // Delete object from HealthKit, log any errors, but do not fail
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.healthStore.deleteObjects(of: self.carbType, predicate: HKQuery.predicateForObject(with: object.uuid!)) { (_, _, healthKitError) in
            error = healthKitError
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        if let error = error {
            self.log.error("Error deleting HealthKit object: %@", String(describing: error))
            return
        }

        // Update Core Data with the change, log any errors, but do not fail
        object.uuid = nil
        if let error = self.cacheStore.save() {
            self.log.error("Error updating CachedCarbObject after deleting HealthKit object: %@", String(describing: error))
        }
    }

    private func addCarbEntry(for sample: HKQuantitySample, on date: Date) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Are there any objects matching the UUID?
        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", sample.uuid as NSUUID)
        request.fetchLimit = 1

        let count = try cacheStore.managedObjectContext.count(for: request)
        guard count == 0 else {
            return false
        }

        // Find all objects being replaced
        let replacedObjects = try fetchRelatedCarbObjects(for: sample)

        // Mark all objects as superceded, as necessary
        replacedObjects.filter({ $0.supercededDate == nil }).forEach({ $0.supercededDate = date })

        // Add an object (create or update) for this UUID
        let object = CachedCarbObject(context: cacheStore.managedObjectContext)
        if let replacedObject = replacedObjects.last {
            object.update(from: sample, replacing: replacedObject, on: date)
        } else {
            object.create(from: sample, on: date)
        }

        return true
    }

    private func deleteCarbEntry(for uuid: UUID, on date: Date) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Fetch objects matching the UUID, if none found, then nothing to delete, sorted by last seen anchor key
        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "anchorKey", ascending: true)]

        let objects = try cacheStore.managedObjectContext.fetch(request)
        guard !objects.isEmpty else {
            return false
        }

        // Find all unsuperceded create/update objects, if none found, then nothing to delete
        let supercededObjects = objects.filter { $0.operation != .delete && $0.supercededDate == nil }
        guard !supercededObjects.isEmpty else {
            return false
        }

        // Mark as superceded
        supercededObjects.forEach { $0.supercededDate = date }

        // If we don't yet have a delete object, then add one
        if !objects.contains(where: { $0.operation == .delete }), let supercededObject = supercededObjects.last {
            let object = CachedCarbObject(context: cacheStore.managedObjectContext)
            object.delete(from: supercededObject, on: date)
        }

        return true
    }

    // Fetch all objects that are different versions of the specified sample, using sync identifier
    private func fetchRelatedCarbObjects(for sample: HKQuantitySample) throws -> [CachedCarbObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        guard let syncIdentifier = sample.syncIdentifier else {
            return []
        }

        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "provenanceIdentifier == %@", sample.provenanceIdentifier),
                                                                                NSPredicate(format: "syncIdentifier == %@", syncIdentifier)])
        request.sortDescriptors = [NSSortDescriptor(key: "anchorKey", ascending: true)]

        return try cacheStore.managedObjectContext.fetch(request)
    }
}

// MARK: - Watch Synchronization

extension CarbStore {

    /// Get carb objects in main app to deliver to Watch extension
    public func getSyncCarbObjects(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: CarbStoreResult<[SyncCarbObject]>) -> Void) {
        queue.async {
            var objects: [SyncCarbObject] = []
            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    objects = try self.getActiveCachedCarbObjects(start: start, end: end).map { SyncCarbObject(managedObject: $0) }
                } catch let coreDataError {
                    error = .coreDataError(coreDataError)
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(objects))
        }
    }

    /// Store carb objects in Watch extension
    public func setSyncCarbObjects(_ objects: [SyncCarbObject], completion: @escaping (CarbStoreError?) -> Void) {
        queue.async {
            if let error = self.purgeCachedCarbObjectsUnconditionally() {
                completion(error)
                return
            }

            var error: CarbStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                guard !objects.isEmpty else {
                    return
                }

                objects.forEach {
                    let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                    object.update(from: $0)
                }

                error = CarbStoreError(error: self.cacheStore.save())
            }

            completion(error)

            self.handleUpdatedCarbData(updateSource: .changedInApp)
        }
    }
}

// MARK: - Cache management

extension CarbStore {
    public var earliestCacheDate: Date {
        return Date(timeIntervalSinceNow: -cacheLength)
    }

    private func purgeExpiredCachedCarbObjects() {
        purgeCachedCarbObjects(before: earliestCacheDate)
    }

    @discardableResult
    private func purgeCachedCarbObjects(before date: Date) -> CarbStoreError? {
        dispatchPrecondition(condition: .onQueue(queue))

        var error: CarbStoreError?

        cacheStore.managedObjectContext.performAndWait {
            do {
                // Fetch all candidate objects for purge
                let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                request.predicate = NSPredicate(format: "startDate < %@", date as NSDate)

                let objects = try self.cacheStore.managedObjectContext.fetch(request)

                // Objects can only be purged if all related objects can be purged
                let purgedObjects = try objects.filter { try self.areAllRelatedObjectsPurgable(to: $0, before: date) }
                guard !purgedObjects.isEmpty else {
                    return
                }

                // Actually purge
                purgedObjects.forEach { self.cacheStore.managedObjectContext.delete($0) }

                if let saveError = CarbStoreError(error: self.cacheStore.save()) {
                    error = saveError
                    return
                }

                self.log.info("Purged %d CachedCarbObjects", purgedObjects.count)
            } catch let coreDataError {
                error = .coreDataError(coreDataError)
            }
        }

        if let error = error {
            self.log.error("Unable to purge CachedCarbObjects: %{public}@", String(describing: error))
            return error
        }

        return nil
    }

    public func purgeCachedCarbObjectsUnconditionally(before date: Date, completion: @escaping (CarbStoreError?) -> Void) {
        queue.async {
            if let error = self.purgeCachedCarbObjectsUnconditionally(before: date) {
                completion(error)
                return
            }

            self.handleUpdatedCarbData(updateSource: .changedInApp)
            completion(nil)
        }
    }

    private func purgeCachedCarbObjectsUnconditionally(before date: Date? = nil) -> CarbStoreError? {
        dispatchPrecondition(condition: .onQueue(queue))

        var error: CarbStoreError?

        cacheStore.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                if let date = date {
                    request.predicate = NSPredicate(format: "startDate < %@", date as NSDate)
                }
                let count = try self.cacheStore.managedObjectContext.deleteObjects(matching: request)
                self.log.info("Purged all %d CachedCarbObjects", count)
            } catch let coreDataError {
                self.log.error("Unable to purge all CachedCarbObjects: %{public}@", String(describing: coreDataError))
                error = .coreDataError(coreDataError)
            }
        }

        return error
    }

    private func handleUpdatedCarbData(updateSource: UpdateSource) {
        dispatchPrecondition(condition: .onQueue(queue))

        purgeExpiredCachedCarbObjects()

        NotificationCenter.default.post(name: CarbStore.carbEntriesDidChange, object: self, userInfo: [CarbStore.notificationUpdateSourceKey: updateSource.rawValue])
        delegate?.carbStoreHasUpdatedCarbData(self)
    }

    private func areAllRelatedObjectsPurgable(to object: CachedCarbObject, before date: Date) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // If no provenance identifier nor sync identifier, then there are no related objects
        guard let provenanceIdentifier = object.provenanceIdentifier, let syncIdentifier = object.syncIdentifier else {
            return true
        }

        // Count any that are NOT purgable
        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "provenanceIdentifier == %@", provenanceIdentifier),
                                                                                NSPredicate(format: "syncIdentifier == %@", syncIdentifier),
                                                                                NSPredicate(format: "startDate >= %@", date as NSDate)])
        request.fetchLimit = 1

        return try cacheStore.managedObjectContext.count(for: request) == 0
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
        getCarbsOnBoardValues(start: date.addingTimeInterval(-delta), end: date, effectVelocities: effectVelocities) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let values):
                guard let value = values.closestPrior(to: date) else {
                    // If we have no cob values in the store, and did not encounter an error, return 0
                    completion(.success(CarbValue(startDate: date, quantity: HKQuantity(unit: .gram(), doubleValue: 0))))
                    return
                }
                completion(.success(value))
            }
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
    public func getCarbsOnBoardValues(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping (_ result: CarbStoreResult<[CarbValue]>) -> Void) {
        // To know COB at the requested start date, we need to fetch samples that might still be absorbing
        let foodStart = start.addingTimeInterval(-maximumAbsorptionTimeInterval)
        getCarbEntries(start: foodStart, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let entries):
                let carbsOnBoard = self.carbsOnBoard(from: entries, startingAt: start, endingAt: end, effectVelocities: effectVelocities)
                completion(.success(carbsOnBoard))
            }
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
    public func getGlucoseEffects(start: Date, end: Date? = nil, effectVelocities: [GlucoseEffectVelocity]? = nil, completion: @escaping(_ result: CarbStoreResult<(entries: [StoredCarbEntry], effects: [GlucoseEffect])>) -> Void) {
        queue.async {
            guard self.carbRatioSchedule != nil, self.insulinSensitivitySchedule != nil else {
                completion(.failure(.notConfigured))
                return
            }

            // To know glucose effects at the requested start date, we need to fetch samples that might still be absorbing
            let foodStart = start.addingTimeInterval(-self.maximumAbsorptionTimeInterval)
            
            self.getCarbEntries(start: foodStart, end: end) { (result) in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let entries):
                    do {
                        let effects = try self.glucoseEffects(of: entries, startingAt: start, endingAt: end, effectVelocities: effectVelocities)
                        completion(.success((entries: entries, effects: effects)))
                    } catch let error as CarbStoreError {
                        completion(.failure(error))
                    } catch {
                        fatalError()
                    }
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
        getCarbEntries(start: start) { (result) in
            switch result {
            case .success(let samples):
                let total = samples.totalCarbs ?? CarbValue(
                    startDate: start,
                    quantity: HKQuantity(unit: .gram(), doubleValue: 0)
                )

                completion(.success(total))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Remote Data Service Query

extension CarbStore {
    public struct QueryAnchor: RawRepresentable {
        public typealias RawValue = [String: Any]

        internal var anchorKey: Int64

        public init() {
            self.anchorKey = 0
        }

        public init?(rawValue: RawValue) {
            guard let anchorKey = (rawValue["anchorKey"] ?? rawValue["storedModificationCounter"]) as? Int64 else {     // Backwards compatibility with storedModificationCounter
                return nil
            }
            self.anchorKey = anchorKey
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["anchorKey"] = anchorKey
            return rawValue
        }
    }

    public enum CarbQueryResult {
        case success(QueryAnchor, [SyncCarbObject], [SyncCarbObject], [SyncCarbObject])
        case failure(Error)
    }

    public func executeCarbQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (CarbQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryCreatedResult = [SyncCarbObject]()
            var queryUpdatedResult = [SyncCarbObject]()
            var queryDeletedResult = [SyncCarbObject]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, [], [], []))
                return
            }

            self.cacheStore.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                storedRequest.predicate = NSPredicate(format: "anchorKey > %d", queryAnchor.anchorKey)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "anchorKey", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let anchorKey = stored.max(by: { $0.anchorKey < $1.anchorKey })?.anchorKey {
                        queryAnchor.anchorKey = anchorKey
                    }
                    stored.map({ SyncCarbObject(managedObject: $0) }).forEach {
                        switch $0.operation {
                        case .create:
                            queryCreatedResult.append($0)
                        case .update:
                            queryUpdatedResult.append($0)
                        case .delete:
                            queryDeletedResult.append($0)
                        }
                    }

                } catch let coreDataError {
                    queryError = coreDataError
                    return
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryCreatedResult, queryUpdatedResult, queryDeletedResult))
        }
    }
}

// MARK: - Critical Event Log Export

extension CarbStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Carbs.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.cacheStore.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
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
        var anchorKey: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "anchorKey > %d", anchorKey),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "anchorKey", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder.encode(objects)

                    anchorKey = objects.last!.anchorKey

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
        var addedDatePredicate = NSPredicate(format: "addedDate >= %@", startDate as NSDate)
        var supercededDatePredicate = NSPredicate(format: "supercededDate >= %@", startDate as NSDate)
        if let endDate = endDate {
            addedDatePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [addedDatePredicate, NSPredicate(format: "addedDate < %@", endDate as NSDate)])
            supercededDatePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [supercededDatePredicate, NSPredicate(format: "supercededDate < %@", endDate as NSDate)])
        }
        return NSCompoundPredicate(orPredicateWithSubpredicates: [addedDatePredicate, supercededDatePredicate])
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension CarbStore {
    public func addNewCarbEntries(entries: [NewCarbEntry], completion: @escaping (Error?) -> Void) {
        guard !entries.isEmpty else {
            completion(nil)
            return
        }

        queue.async {
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    for entry in entries {
                        let syncIdentifier = try self.cacheStore.managedObjectContext.generateUniqueSyncIdentifier()

                        let object = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                        object.create(from: entry,
                                      provenanceIdentifier: self.provenanceIdentifier,
                                      syncIdentifier: syncIdentifier,
                                      on: entry.date)
                    }
                    error = self.cacheStore.save()
                } catch let coreDataError {
                    error = coreDataError
                }
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
}

// MARK: - Issue Report

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
                "cachedCarbEntries:"
            ]

            switch self.getCarbEntries() {
            case .failure(let error):
                report.append("Error: \(error)")
            case .success(let entries):
                report.append("[")
                report.append("\tStoredCarbEntry(uuid, provenanceIdentifier, syncIdentifier, syncVersion, startDate, quantity, foodType, absorptionTime, createdByCurrentApp, userCreatedDate, userUpdatedDate)")
                report.append(entries.map({ (entry) -> String in
                    return [
                        "\t",
                        entry.uuid?.uuidString ?? "",
                        entry.provenanceIdentifier ?? "",
                        entry.syncIdentifier ?? "",
                        entry.syncVersion != nil ? String(describing: entry.syncVersion) : "",
                        String(describing: entry.startDate),
                        String(describing: entry.quantity),
                        entry.foodType ?? "",
                        String(describing: entry.absorptionTime ?? self.defaultAbsorptionTimes.medium),
                        String(describing: entry.createdByCurrentApp),
                        entry.userCreatedDate != nil ? String(describing: entry.userCreatedDate) : "",
                        entry.userUpdatedDate != nil ? String(describing: entry.userUpdatedDate) : "",
                    ].joined(separator: ", ")
                }).joined(separator: "\n"))
                report.append("]")
                report.append("")
            }

            completionHandler(report.joined(separator: "\n"))
        }
    }
}

// MARK: - NSManagedObjectContext

fileprivate extension NSManagedObjectContext {
    func generateUniqueSyncIdentifier() throws -> String {
        while true {
            let syncIdentifier = UUID().uuidString

            let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
            request.predicate = NSPredicate(format: "syncIdentifier == %@", syncIdentifier)
            request.fetchLimit = 1

            if try count(for: request) == 0 {
                return syncIdentifier
            }
        }
    }

    func cachedCarbObjectFromStoredCarbEntry(_ entry: StoredCarbEntry) throws -> CachedCarbObject? {
        guard entry.createdByCurrentApp, let syncIdentifier = entry.syncIdentifier, let syncVersion = entry.syncVersion else {
            return nil
        }

        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "createdByCurrentApp == YES"),
            NSPredicate(format: "syncIdentifier == %@", syncIdentifier),
            NSPredicate(format: "syncVersion == %d", syncVersion),
            NSPredicate(format: "operation != %d", Operation.delete.rawValue),
            NSPredicate(format: "supercededDate == NIL")
        ])
        request.fetchLimit = 1

        if let object = try fetch(request).first {
            return object
        }

        return try cachedCarbObjectFromStoredCarbEntryDEPRECATED(entry)
    }

    // DEPRECATED: Fallback for pre-syncIdentifier entries, just has UUID from HealthKit
    func cachedCarbObjectFromStoredCarbEntryDEPRECATED(_ entry: StoredCarbEntry) throws -> CachedCarbObject? {
        guard entry.createdByCurrentApp, let uuid = entry.uuid else {
            return nil
        }

        let request: NSFetchRequest<CachedCarbObject> = CachedCarbObject.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "createdByCurrentApp == YES"),
            NSPredicate(format: "uuid == %@", uuid as NSUUID),
            NSPredicate(format: "operation != %d", Operation.delete.rawValue),
            NSPredicate(format: "supercededDate == NIL")
        ])
        request.fetchLimit = 1

        if let object = try fetch(request).first {
            return object
        }

        return nil
    }
}
