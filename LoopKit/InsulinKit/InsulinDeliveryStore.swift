//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit
import CoreData
import os.log

public protocol InsulinDeliveryStoreDelegate: AnyObject {

    /**
     Informs the delegate that the insulin delivery store has updated dose data.

     - Parameter insulinDeliveryStore: The insulin delivery store that has updated dose data.
     */
    func insulinDeliveryStoreHasUpdatedDoseData(_ insulinDeliveryStore: InsulinDeliveryStore)

}

/// Manages insulin dose data in Core Data and optionally reads insulin dose data from HealthKit.
///
/// Scheduled doses (e.g. a bolus or temporary basal) shouldn't be written to this store until they've
/// been delivered into the patient, which means its common for this store data to slightly lag
/// behind the dose data used for algorithmic calculation.
///
/// This store data isn't a substitute for an insulin pump's diagnostic event history, but doses fetched
/// from this store can reduce the amount of repeated communication with an insulin pump.
public class InsulinDeliveryStore: HealthKitSampleStore {
    
    /// Notification posted when dose entries were changed, either via direct add or from HealthKit
    public static let doseEntriesDidChange = NSNotification.Name(rawValue: "com.loopkit.InsulinDeliveryStore.doseEntriesDidChange")

    private let insulinQuantityType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    private let queue = DispatchQueue(label: "com.loopkit.InsulinDeliveryStore.queue", qos: .utility)

    private let log = OSLog(category: "InsulinDeliveryStore")

    /// The most-recent end date for an immutable basal dose entry written by LoopKit
    /// Should only be accessed on queue
    private var lastImmutableBasalEndDate: Date? {
        didSet {
            test_lastImmutableBasalEndDateDidSet?()
        }
    }

    internal var test_lastImmutableBasalEndDateDidSet: (() -> Void)?

    public weak var delegate: InsulinDeliveryStoreDelegate?

    /// The interval of insulin delivery data to keep in cache
    public let cacheLength: TimeInterval

    private let storeSamplesToHealthKit: Bool

    private let cacheStore: PersistenceController

    private let provenanceIdentifier: String

    static let healthKitQueryAnchorMetadataKey = "com.loopkit.InsulinDeliveryStore.hkQueryAnchor"

    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        storeSamplesToHealthKit: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        provenanceIdentifier: String,
        test_currentDate: Date? = nil
    ) {
        self.storeSamplesToHealthKit = storeSamplesToHealthKit
        self.cacheStore = cacheStore
        self.cacheLength = cacheLength
        self.provenanceIdentifier = provenanceIdentifier

        // Only observe HK driven changes from last 24 hours
        let observationStartOffset = min(cacheLength, .hours(24))

        super.init(
            healthStore: healthStore,
            observeHealthKitSamplesFromCurrentApp: true,
            observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
            type: insulinQuantityType,
            observationStart: (test_currentDate ?? Date()).addingTimeInterval(-observationStartOffset),
            observationEnabled: observationEnabled,
            test_currentDate: test_currentDate
        )

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            guard error == nil else {
                semaphore.signal()
                return
            }

            cacheStore.fetchAnchor(key: InsulinDeliveryStore.healthKitQueryAnchorMetadataKey) { (anchor) in
                self.queue.async {
                    self.queryAnchor = anchor

                    if !self.authorizationRequired {
                        self.createQuery()
                    }

                    self.updateLastImmutableBasalEndDate()

                    semaphore.signal()
                }
            }
        }
        semaphore.wait()
    }
    
    // MARK: - HealthKitSampleStore

    override func queryAnchorDidChange() {
        cacheStore.storeAnchor(queryAnchor, key: InsulinDeliveryStore.healthKitQueryAnchorMetadataKey)
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
                            if try self.addDoseEntry(for: sample) {
                                self.log.debug("Saved sample %@ into cache from HKAnchoredObjectQuery", sample.uuid.uuidString)
                                changed = true
                            } else {
                                self.log.default("Sample %@ from HKAnchoredObjectQuery already present in cache", sample.uuid.uuidString)
                            }
                        }
                    }

                    // Delete deleted samples
                    let count = try self.deleteDoseEntries(withUUIDs: deleted.map { $0.uuid })
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

            guard error == nil else {
                completion(false)
                return
            }

            guard changed else {
                completion(true)
                return
            }

            self.handleUpdatedDoseData()
            self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)

            completion(true)
        }
    }
}

// MARK: - Fetching

extension InsulinDeliveryStore {
    /// Retrieves dose entries within the specified date range.
    ///
    /// - Parameters:
    ///   - start: The earliest date of dose entries to retrieve, if provided.
    ///   - end: The latest date of dose entries to retrieve, if provided.
    ///   - includeMutable: Whether to include mutable dose entries or not. Defaults to false.
    ///   - completion: A closure called once the dose entries have been retrieved.
    ///   - result: An array of dose entries, in chronological order by startDate, or error.
    public func getDoseEntries(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false, completion: @escaping (_ result: Result<[DoseEntry], Error>) -> Void) {
        queue.async {
            completion(self.getDoseEntries(start: start, end: end, includeMutable: includeMutable))
        }
    }

    private func getDoseEntries(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false) -> Result<[DoseEntry], Error> {
        dispatchPrecondition(condition: .onQueue(queue))

        var entries: [DoseEntry] = []
        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                entries = try self.getCachedInsulinDeliveryObjects(start: start, end: end, includeMutable: includeMutable).map { $0.dose }
            } catch let coreDataError {
                error = coreDataError
            }
        }

        if let error = error {
            self.log.error("Error getting CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
            return .failure(error)
        }

        return .success(entries)
    }

    private func getCachedInsulinDeliveryObjects(start: Date? = nil, end: Date? = nil, includeMutable: Bool = false) throws -> [CachedInsulinDeliveryObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        // Match all doses whose start OR end dates fall in the start and end date range, if specified. Therefore, we ensure the
        // dose end date is AFTER the start date, if specified, and the dose start date is BEFORE the end date, if specified.
        var predicates = [NSPredicate(format: "deletedAt == NIL")]
        if let start = start {
            predicates.append(NSPredicate(format: "endDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate <= %@", end as NSDate))    // Note: Using <= rather than < to match previous behavior
        }
        if !includeMutable {
            predicates.append(NSPredicate(format: "isMutable == NO"))
        }

        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        request.predicate = (predicates.count > 1) ? NSCompoundPredicate(andPredicateWithSubpredicates: predicates) : predicates.first
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
    }

    /// Fetches manually entered doses.
    ///
    /// - Parameters:
    ///   - startDate: The earliest dose startDate to include.
    ///   - chronological: Whether to return the objects in chronological or reverse-chronological order.
    ///   - limit: The maximum number of manually entered dose entries to return.
    /// - Returns: An array of manually entered dose dose entries in the specified order by date.
    public func getManuallyEnteredDoses(since startDate: Date, chronological: Bool = true, limit: Int? = nil, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        queue.async {
            var doses: [DoseEntry] = []
            var error: DoseStore.DoseStoreError?

            self.cacheStore.managedObjectContext.performAndWait {
                let predicates = [NSPredicate(format: "deletedAt == NIL"),
                                  NSPredicate(format: "startDate >= %@", startDate as NSDate),
                                  NSPredicate(format: "manuallyEntered == YES")]

                let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: chronological)]
                if let limit = limit {
                    request.fetchLimit = limit
                }

                do {
                    doses = try self.cacheStore.managedObjectContext.fetch(request).compactMap{ $0.dose }
                } catch let fetchError as NSError {
                    error = .fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
                } catch {
                    assertionFailure()
                }
            }

            if let error = error {
                completion(.failure(error))
            }

            completion(.success(doses))
        }
    }

    /// Returns the end date of the most recent basal dose entry.
    ///
    /// - Parameters:
    ///   - completion: A closure called when the date has been retrieved with date.
    ///   - result: The date, or error.
    func getLastImmutableBasalEndDate(_ completion: @escaping (_ result: Result<Date, Error>) -> Void) {
        queue.async {
            switch self.lastImmutableBasalEndDate {
            case .some(let date):
                completion(.success(date))
            case .none:
                // TODO: send a proper error
                completion(.failure(DoseStore.DoseStoreError.configurationError))
            }
        }
    }

    private func updateLastImmutableBasalEndDate() {
        dispatchPrecondition(condition: .onQueue(queue))

        var endDate: Date?

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                    NSPredicate(format: "reason == %d", HKInsulinDeliveryReason.basal.rawValue),
                                                                                    NSPredicate(format: "hasLoopKitOrigin == YES"),
                                                                                    NSPredicate(format: "isMutable == NO")])
            request.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
            request.fetchLimit = 1

            do {
                let objects = try self.cacheStore.managedObjectContext.fetch(request)

                endDate = objects.first?.endDate
            } catch let error {
                self.log.error("Unable to fetch latest insulin delivery objects: %@", String(describing: error))
            }
        }

        self.lastImmutableBasalEndDate = endDate ?? .distantPast
    }
}

// MARK: - Modification

extension InsulinDeliveryStore {
    /// Add dose entries to store.
    ///
    /// - Parameters:
    ///   - entries: The new dose entries to add to the store.
    ///   - device: The optional device used for the new dose entries.
    ///   - syncVersion: The sync version used for the new dose entries.
    ///   - resolveMutable: Whether to update or delete any pre-existing mutable dose entries based upon any matching incoming mutable dose entries.
    ///   - completion: A closure called once the dose entries have been stored.
    ///   - result: Success or error.
    func addDoseEntries(_ entries: [DoseEntry], from device: HKDevice?, syncVersion: Int, resolveMutable: Bool = false, completion: @escaping (_ result: Result<Void, Error>) -> Void) {
        guard !entries.isEmpty else {
            completion(.success(()))
            return
        }

        queue.async {
            var changed = false
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let now = self.currentDate()
                    var mutableObjects: [CachedInsulinDeliveryObject] = []

                    // If we are resolving mutable objects, then fetch all non-deleted mutable objects and initially mark as deleted
                    // If an incoming entry matches via syncIdentifier, then update and mark as NOT deleted
                    if resolveMutable {
                        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                                NSPredicate(format: "isMutable == YES")])
                        mutableObjects = try self.cacheStore.managedObjectContext.fetch(request)
                        mutableObjects.forEach { $0.deletedAt = now }
                    }

                    let resolvedSampleObjects: [(HKQuantitySample, CachedInsulinDeliveryObject)] = entries.compactMap { entry in
                        guard entry.syncIdentifier != nil else {
                            self.log.error("Ignored adding dose entry without sync identifier: %{public}@", String(reflecting: entry))
                            return nil
                        }

                        guard let quantitySample = HKQuantitySample(type: self.insulinQuantityType,
                                                                    unit: HKUnit.internationalUnit(),
                                                                    dose: entry,
                                                                    device: device,
                                                                    provenanceIdentifier: self.provenanceIdentifier,
                                                                    syncVersion: syncVersion)
                        else {
                            self.log.error("Failure to create HKQuantitySample from DoseEntry: %{public}@", String(describing: entry))
                            return nil
                        }

                        // If we have a mutable object that matches this sync identifier, then update, it will mark as NOT deleted
                        if let object = mutableObjects.first(where: { $0.provenanceIdentifier == self.provenanceIdentifier && $0.syncIdentifier == entry.syncIdentifier }) {
                            self.log.debug("Update: %{public}@", String(describing: entry))
                            object.update(from: entry)
                            return (quantitySample, object)

                        // Otherwise, add new object
                        } else {
                            let object = CachedInsulinDeliveryObject(context: self.cacheStore.managedObjectContext)
                            object.create(from: entry, by: self.provenanceIdentifier, at: now)
                            self.log.debug("Add: %{public}@", String(describing: entry))
                            return (quantitySample, object)
                        }
                    }

                    for dose in mutableObjects {
                        if dose.deletedAt != nil {
                            self.log.debug("Delete: %{public}@", String(describing: dose))
                        }
                    }

                    changed = !mutableObjects.isEmpty || !resolvedSampleObjects.isEmpty
                    guard changed else {
                        return
                    }

                    error = self.cacheStore.save()
                    if error != nil {
                        return
                    }

                    // Only save immutable objects to HealthKit
                    self.saveEntriesToHealthKit(resolvedSampleObjects.filter { !$0.1.isMutable && !$0.1.isFault })
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard changed else {
                completion(.success(()))
                return
            }

            self.handleUpdatedDoseData()
            self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)

            completion(.success(()))
        }
    }

    private func saveEntriesToHealthKit(_ sampleObjects: [(HKQuantitySample, CachedInsulinDeliveryObject)]) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard storeSamplesToHealthKit, !sampleObjects.isEmpty else {
            return
        }

        var error: Error?

        // Save objects to HealthKit, log any errors, but do not fail
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        self.healthStore.save(sampleObjects.map { (sample, _) in sample }) { (_, healthKitError) in
            error = healthKitError
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        if let error = error {
            self.log.error("Error saving HealthKit objects: %@", String(describing: error))
            return
        }

        // Update Core Data with the changes, log any errors, but do not fail
        sampleObjects.forEach { (sample, object) in object.uuid = sample.uuid }
        if let error = self.cacheStore.save() {
            self.log.error("Error updating CachedInsulinDeliveryObjects after saving HealthKit objects: %@", String(describing: error))
            sampleObjects.forEach { (_, object) in object.uuid = nil }
        }
    }

    private func addDoseEntry(for sample: HKQuantitySample) throws -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        // Is entire sample before earliest cache date?
        guard sample.endDate >= earliestCacheDate else {
            return false
        }

        // Are there any objects matching the UUID?
        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", sample.uuid as NSUUID)
        request.fetchLimit = 1

        let count = try cacheStore.managedObjectContext.count(for: request)
        guard count == 0 else {
            return false
        }

        // Add an object for this UUID
        let object = CachedInsulinDeliveryObject(context: cacheStore.managedObjectContext)
        object.create(fromExisting: sample, on: self.currentDate())

        return true
    }
    
    func deleteDose(bySyncIdentifier syncIdentifier: String, _ completion: @escaping (String?) -> Void) {
        queue.async {
            var errorString: String? = nil
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                            NSPredicate(format: "syncIdentifier == %@", syncIdentifier)])
                    request.fetchBatchSize = 100
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if !objects.isEmpty {
                        let deletedAt = self.currentDate()
                        for object in objects {
                            object.deletedAt = deletedAt
                        }
                        self.cacheStore.save()
                    }
                    
                    let healthKitPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [syncIdentifier])
                    self.healthStore.deleteObjects(of: self.insulinQuantityType, predicate: healthKitPredicate)
                    { success, deletedObjectCount, error in
                        if let error = error {
                            self.log.error("Unable to delete dose from Health: %@", error.localizedDescription)
                        }
                    }
                } catch let error {
                    errorString = "Error deleting CachedInsulinDeliveryObject: " + error.localizedDescription
                    return
                }
            }
            self.handleUpdatedDoseData()
            self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)
            completion(errorString)
        }
    }

    func deleteDose(with uuidToDelete: UUID, _ completion: @escaping (String?) -> Void) {
        queue.async {
            var errorString: String? = nil
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let count = try self.deleteDoseEntries(withUUIDs: [uuidToDelete])
                    guard count > 0 else {
                        errorString = "Cannot find CachedInsulinDeliveryObject to delete"
                        return
                    }
                    self.cacheStore.save()
                } catch let error {
                    errorString = "Error deleting CachedInsulinDeliveryObject: " + error.localizedDescription
                    return
                }
            }
            self.handleUpdatedDoseData()
            self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)
            completion(errorString)
        }
    }

    private func deleteDoseEntries(withUUIDs uuids: [UUID], batchSize: Int = 500) throws -> Int {
        dispatchPrecondition(condition: .onQueue(queue))

        let deletedAt = self.currentDate()

        var count = 0
        for batch in uuids.chunked(into: batchSize) {
            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                    NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID })])
            let objects = try self.cacheStore.managedObjectContext.fetch(request)
            for object in objects {
                object.deletedAt = deletedAt
            }
            count += objects.count
        }
        return count
    }

    public func deleteAllManuallyEnteredDoses(since startDate: Date, _ completion: @escaping (_ error: DoseStore.DoseStoreError?) -> Void) {
        queue.async {
            var doseStoreError: DoseStore.DoseStoreError?
            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "deletedAt == NIL"),
                                                                                            NSPredicate(format: "startDate >= %@", startDate as NSDate),
                                                                                            NSPredicate(format: "manuallyEntered == YES")])
                    request.fetchBatchSize = 100
                    let objects = try self.cacheStore.managedObjectContext.fetch(request)
                    if !objects.isEmpty {
                        let deletedAt = self.currentDate()
                        for object in objects {
                            object.deletedAt = deletedAt
                        }
                        doseStoreError = DoseStore.DoseStoreError(error: self.cacheStore.save())
                    }
                }
                catch let error as NSError {
                    doseStoreError = DoseStore.DoseStoreError(error: .coreDataError(error))
                }
            }
            self.handleUpdatedDoseData()
            self.delegate?.insulinDeliveryStoreHasUpdatedDoseData(self)
            completion(doseStoreError)
        }
    }
}

// MARK: - Cache Management

extension InsulinDeliveryStore {
    var earliestCacheDate: Date {
        return currentDate(timeIntervalSinceNow: -cacheLength)
    }

    /// Purge all dose entries from the insulin delivery store and HealthKit (matching the specified device predicate).
    ///
    /// - Parameters:
    ///   - healthKitPredicate: The HealthKit device predicate to match HealthKit insulin samples.
    ///   - completion: The completion handler returning any error.
    public func purgeAllDoseEntries(healthKitPredicate: NSPredicate, completion: @escaping (Error?) -> Void) {
        queue.async {
            let storeError = self.purgeCachedInsulinDeliveryObjects(matching: nil)
            self.healthStore.deleteObjects(of: self.insulinQuantityType, predicate: healthKitPredicate) { _, _, healthKitError in
                self.queue.async {
                    self.handleUpdatedDoseData()
                    completion(storeError ?? healthKitError)
                }
            }
        }
    }

    private func purgeExpiredCachedInsulinDeliveryObjects() {
        purgeCachedInsulinDeliveryObjects(before: earliestCacheDate)
    }

    /// Purge cached insulin delivery objects from the insulin delivery store.
    ///
    /// - Parameters:
    ///   - date: Purge cached insulin delivery objects with start date before this date.
    ///   - completion: The completion handler returning any error.
    public func purgeCachedInsulinDeliveryObjects(before date: Date? = nil, completion: @escaping (Error?) -> Void) {
        queue.async {
            if let error = self.purgeCachedInsulinDeliveryObjects(before: date) {
                completion(error)
                return
            }
            self.handleUpdatedDoseData()
            completion(nil)
        }
    }

    @discardableResult
    private func purgeCachedInsulinDeliveryObjects(before date: Date? = nil) -> Error? {
        return purgeCachedInsulinDeliveryObjects(matching: date.map { NSPredicate(format: "endDate < %@", $0 as NSDate) })
    }

    private func purgeCachedInsulinDeliveryObjects(matching predicate: NSPredicate? = nil) -> Error? {
        dispatchPrecondition(condition: .onQueue(queue))

        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                let count = try cacheStore.managedObjectContext.purgeObjects(of: CachedInsulinDeliveryObject.self, matching: predicate)
                if count > 0 {
                    self.log.default("Purged %d CachedInsulinDeliveryObjects", count)
                }
            } catch let coreDataError {
                self.log.error("Unable to purge CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
                error = coreDataError
            }
        }

        return error
    }

    private func handleUpdatedDoseData() {
        dispatchPrecondition(condition: .onQueue(queue))

        self.purgeExpiredCachedInsulinDeliveryObjects()
        self.updateLastImmutableBasalEndDate()

        NotificationCenter.default.post(name: InsulinDeliveryStore.doseEntriesDidChange, object: self)
    }
}

// MARK: - Issue Report

extension InsulinDeliveryStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completion: The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void) {
        self.queue.async {
            var report: [String] = [
                "### InsulinDeliveryStore",
                "* cacheLength: \(self.cacheLength)",
                super.debugDescription,
                "* lastImmutableBasalEndDate: \(String(describing: self.lastImmutableBasalEndDate))",
                "",
                "#### cachedDoseEntries",
            ]

            switch self.getDoseEntries(start: Date(timeIntervalSinceNow: -.hours(24)), includeMutable: true) {
            case .failure(let error):
                report.append("Error: \(error)")
            case .success(let entries):
                for entry in entries {
                    report.append(String(describing: entry))
                }
            }

            report.append("")
            completion(report.joined(separator: "\n"))
        }
    }
}

// MARK: - Query

extension InsulinDeliveryStore {

    public struct QueryAnchor: Equatable, RawRepresentable {

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

    public enum DoseQueryResult {
        case success(QueryAnchor, [DoseEntry], [DoseEntry])
        case failure(Error)
    }

    public func executeDoseQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DoseQueryResult) -> Void) {
        queue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryCreatedResult = [DoseEntry]()
            var queryDeletedResult = [DoseEntry]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, [], []))
                return
            }

            self.cacheStore.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryCreatedResult.append(contentsOf: stored.filter({ $0.deletedAt == nil }).compactMap { $0.dose })
                    queryDeletedResult.append(contentsOf: stored.filter({ $0.deletedAt != nil }).compactMap { $0.dose })
                } catch let error {
                    queryError = error
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryCreatedResult, queryDeletedResult))
        }
    }
}

// MARK: - Unit Testing

extension InsulinDeliveryStore {
    public var test_lastImmutableBasalEndDate: Date? {
        get {
            var date: Date?
            queue.sync {
                date = self.lastImmutableBasalEndDate
            }
            return date
        }
        set {
            queue.sync {
                self.lastImmutableBasalEndDate = newValue
            }
        }
    }
}
