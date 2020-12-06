//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit
import CoreData
import os.log

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

    private let insulinType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    private let queue = DispatchQueue(label: "com.loopkit.InsulinDeliveryStore.queue", qos: .utility)

    private let log = OSLog(category: "InsulinDeliveryStore")

    /// The most-recent end date for a basal dose entry written by LoopKit
    /// Should only be accessed on queue
    private var lastBasalEndDate: Date? {
        didSet {
            test_lastBasalEndDateDidSet?()
        }
    }

    internal var test_lastBasalEndDateDidSet: (() -> Void)?

    /// The interval of insulin delivery data to keep in cache
    public let cacheLength: TimeInterval

    private let cacheStore: PersistenceController

    private let provenanceIdentifier: String

    static let healthKitQueryAnchorMetadataKey = "com.loopkit.InsulinDeliveryStore.hkQueryAnchor"

    public init(
        healthStore: HKHealthStore,
        observeHealthKitSamplesFromOtherApps: Bool = true,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        provenanceIdentifier: String,
        test_currentDate: Date? = nil
    ) {
        self.cacheStore = cacheStore
        self.cacheLength = cacheLength
        self.provenanceIdentifier = provenanceIdentifier

        super.init(
            healthStore: healthStore,
            observeHealthKitSamplesFromCurrentApp: false,
            observeHealthKitSamplesFromOtherApps: observeHealthKitSamplesFromOtherApps,
            type: insulinType,
            observationStart: (test_currentDate ?? Date()).addingTimeInterval(-cacheLength),
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

                    self.updateLastBasalEndDate()

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

            if error != nil {
                completion(false)
                return
            }

            if !changed {
                completion(true)
                return
            }

            self.handleUpdatedDoseData(updateSource: .queriedByHealthKit)
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
    ///   - completion: A closure called once the dose entries have been retrieved.
    ///   - result: An array of dose entries, in chronological order by startDate, or error.
    public func getDoseEntries(start: Date? = nil, end: Date? = nil, completion: @escaping (_ result: Result<[DoseEntry], Error>) -> Void) {
        queue.async {
            completion(self.getDoseEntries(start: start, end: end))
        }
    }

    private func getDoseEntries(start: Date? = nil, end: Date? = nil) -> Result<[DoseEntry], Error> {
        dispatchPrecondition(condition: .onQueue(queue))

        var entries: [DoseEntry] = []
        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                entries = try self.getCachedInsulinDeliveryObjects(start: start, end: end).map { $0.dose }
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

    private func getCachedInsulinDeliveryObjects(start: Date? = nil, end: Date? = nil) throws -> [CachedInsulinDeliveryObject] {
        dispatchPrecondition(condition: .onQueue(queue))

        // Match all doses whose start OR end dates fall in the start and end date range, if specified. Therefore, we ensure the
        // dose end date is AFTER the start date, if specified, and the dose start date is BEFORE the end date, if specified.
        var predicates: [NSPredicate] = []
        if let start = start {
            predicates.append(NSPredicate(format: "endDate >= %@", start as NSDate))
        }
        if let end = end {
            predicates.append(NSPredicate(format: "startDate <= %@", end as NSDate))    // Note: Using <= rather than < to match previous behavior
        }

        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        request.predicate = (predicates.count > 1) ? NSCompoundPredicate(andPredicateWithSubpredicates: predicates) : predicates.first
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]

        return try self.cacheStore.managedObjectContext.fetch(request)
    }

    /// Returns the end date of the most recent basal dose entry.
    ///
    /// - Parameters:
    ///   - completion: A closure called when the date has been retrieved with date.
    ///   - result: The date, or error.
    func getLastBasalEndDate(_ completion: @escaping (_ result: Result<Date, Error>) -> Void) {
        queue.async {
            switch self.lastBasalEndDate {
            case .some(let date):
                completion(.success(date))
            case .none:
                // TODO: send a proper error
                completion(.failure(DoseStore.DoseStoreError.configurationError))
            }
        }
    }

    private func updateLastBasalEndDate() {
        dispatchPrecondition(condition: .onQueue(queue))

        var endDate: Date?

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()

            let basalPredicate = NSPredicate(format: "reason == %d", HKInsulinDeliveryReason.basal.rawValue)
            let sourcePredicate = NSPredicate(format: "hasLoopKitOrigin == true")
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [basalPredicate, sourcePredicate])

            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "endDate", ascending: false)]
            request.fetchLimit = 1

            do {
                let objects = try self.cacheStore.managedObjectContext.fetch(request)

                endDate = objects.first?.endDate
            } catch let error {
                self.log.error("Unable to fetch latest insulin delivery objects: %@", String(describing: error))
            }
        }

        self.lastBasalEndDate = endDate ?? .distantPast
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
    ///   - completion: A closure called once the dose entries have been stored.
    ///   - result: Success or error.
    func addDoseEntries(_ entries: [DoseEntry], from device: HKDevice?, syncVersion: Int, completion: @escaping (_ result: Result<Void, Error>) -> Void) {
        guard !entries.isEmpty else {
            completion(.success(()))
            return
        }

        queue.async {
            var changed = false
            var error: Error?

            self.cacheStore.managedObjectContext.performAndWait {
                do {
                    let quantitySamples: [HKQuantitySample] = try entries.compactMap { entry in
                        guard let syncIdentifier = entry.syncIdentifier else {
                            self.log.error("Ignored adding dose entry without sync identifier: %{public}@", String(reflecting: entry))
                            return nil
                        }

                        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
                        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "provenanceIdentifier == %@", self.provenanceIdentifier),
                                                                                                NSPredicate(format: "syncIdentifier == %@", syncIdentifier)])
                        request.fetchLimit = 1

                        guard try self.cacheStore.managedObjectContext.count(for: request) == 0 else {
                            self.log.default("Skipping adding dose entry due to existing cached sync identifier: %{public}@", syncIdentifier)
                            return nil
                        }

                        return HKQuantitySample(type: self.insulinType, unit: HKUnit.internationalUnit(), dose: entry, device: device, syncVersion: syncVersion)
                    }

                    changed = !quantitySamples.isEmpty
                    guard changed else {
                        return
                    }

                    let objects: [CachedInsulinDeliveryObject] = quantitySamples.map { quantitySample in
                        let object = CachedInsulinDeliveryObject(context: self.cacheStore.managedObjectContext)
                        object.create(fromNew: quantitySample, provenanceIdentifier: self.provenanceIdentifier, on: self.currentDate())
                        return object
                    }

                    error = self.cacheStore.save()
                    if error != nil {
                        return
                    }

                    self.saveEntriesToHealthKit(quantitySamples, objects: objects)
                } catch let coreDataError {
                    error = coreDataError
                }
            }

            if let error = error {
                completion(.failure(error))
                return
            }

            if !changed {
                completion(.success(()))
                return
            }

            self.handleUpdatedDoseData(updateSource: .changedInApp)
            completion(.success(()))
        }
    }

    private func saveEntriesToHealthKit(_ quantitySamples: [HKQuantitySample], objects: [CachedInsulinDeliveryObject]) {
        dispatchPrecondition(condition: .onQueue(queue))

        guard !quantitySamples.isEmpty else {
            return
        }

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
            self.log.error("Error updating CachedInsulinDeliveryObjects after saving HealthKit objects: %@", String(describing: error))
            objects.forEach { $0.uuid = nil }
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

    private func deleteDoseEntries(withUUIDs uuids: [UUID], batchSize: Int = 500) throws -> Int {
        dispatchPrecondition(condition: .onQueue(queue))

        var count = 0
        for batch in uuids.chunked(into: batchSize) {
            let predicate = NSPredicate(format: "uuid IN %@", batch.map { $0 as NSUUID })
            count += try cacheStore.managedObjectContext.purgeObjects(of: CachedInsulinDeliveryObject.self, matching: predicate)
        }
        return count
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
            let storeError = self.purgeCachedInsulinDeliveryObjects()
            self.healthStore.deleteObjects(of: self.insulinType, predicate: healthKitPredicate) { _, _, healthKitError in
                self.queue.async {
                    self.handleUpdatedDoseData(updateSource: .changedInApp)
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
            self.handleUpdatedDoseData(updateSource: .changedInApp)
            completion(nil)
        }
    }

    @discardableResult
    private func purgeCachedInsulinDeliveryObjects(before date: Date? = nil) -> Error? {
        dispatchPrecondition(condition: .onQueue(queue))

        var error: Error?

        cacheStore.managedObjectContext.performAndWait {
            do {
                var predicate: NSPredicate?
                if let date = date {
                    predicate = NSPredicate(format: "endDate < %@", date as NSDate)
                }
                let count = try cacheStore.managedObjectContext.purgeObjects(of: CachedInsulinDeliveryObject.self, matching: predicate)
                self.log.default("Purged %d CachedInsulinDeliveryObjects", count)
            } catch let coreDataError {
                self.log.error("Unable to purge CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
                error = coreDataError
            }
        }

        return error
    }

    private func handleUpdatedDoseData(updateSource: UpdateSource) {
        dispatchPrecondition(condition: .onQueue(queue))

        self.purgeExpiredCachedInsulinDeliveryObjects()
        self.updateLastBasalEndDate()

        NotificationCenter.default.post(name: InsulinDeliveryStore.doseEntriesDidChange, object: self, userInfo: [InsulinDeliveryStore.notificationUpdateSourceKey: updateSource.rawValue])
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
                "* lastBasalEndDate: \(String(describing: self.lastBasalEndDate))",
                "",
                "#### cachedDoseEntries",
            ]

            switch self.getDoseEntries(start: Date(timeIntervalSinceNow: -.hours(24))) {
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

// MARK: - Unit Testing

extension InsulinDeliveryStore {
    public var test_lastBasalEndDate: Date? {
        get {
            var date: Date?
            queue.sync {
                date = self.lastBasalEndDate
            }
            return date
        }
        set {
            queue.sync {
                self.lastBasalEndDate = newValue
            }
        }
    }
}
