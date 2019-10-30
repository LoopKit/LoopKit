//
//  InsulinDeliveryStore.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit
import CoreData
import os.log

enum InsulinDeliveryStoreResult<T> {
    case success(T)
    case failure(Error)
}

/// Manages insulin dose data from HealthKit
///
/// Scheduled doses (e.g. a bolus or temporary basal) shouldn't be written to HealthKit until they've
/// been delivered into the patient, which means its common for the HealthKit data to slightly lag
/// behind the dose data used for algorithmic calculation.
///
/// HealthKit data isn't a substitute for an insulin pump's diagnostic event history, but doses fetched
/// from HealthKit can reduce the amount of repeated communication with an insulin pump.
public class InsulinDeliveryStore: HealthKitSampleStore {
    
    /// Notification posted when cached data was modifed.
    static let cacheDidChange = NSNotification.Name(rawValue: "com.loopkit.InsulinDeliveryStore.cacheDidChange")

    private let insulinType = HKQuantityType.quantityType(forIdentifier: .insulinDelivery)!

    private let queue = DispatchQueue(label: "com.loopkit.InsulinKit.InsulinDeliveryStore.queue", qos: .utility)

    private let log = OSLog(category: "InsulinDeliveryStore")

    /// The most-recent end date for a basal sample written by LoopKit
    /// Should only be accessed on dataAccessQueue
    private var lastBasalEndDate: Date? {
        didSet {
            test_lastBasalEndDateDidSet?()
        }
    }

    internal var test_lastBasalEndDateDidSet: (() -> Void)?

    /// The interval of insulin delivery data to keep in cache
    public let cacheLength: TimeInterval

    public let cacheStore: PersistenceController

    public init(
        healthStore: HKHealthStore,
        cacheStore: PersistenceController,
        observationEnabled: Bool = true,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        test_currentDate: Date? = nil
    ) {
        self.cacheStore = cacheStore
        self.cacheLength = cacheLength

        super.init(
            healthStore: healthStore,
            type: insulinType,
            observationStart: (test_currentDate ?? Date()).addingTimeInterval(-cacheLength),
            observationEnabled: observationEnabled,
            test_currentDate: test_currentDate
        )

        cacheStore.onReady { (error) in
            // Should we do something here?
        }
    }

    public override func processResults(from query: HKAnchoredObjectQuery, added: [HKSample], deleted: [HKDeletedObject], error: Error?) {
        guard error == nil else {
            return
        }

        queue.async {
            // Added samples
            let samples = ((added as? [HKQuantitySample]) ?? []).filterDateRange(self.earliestCacheDate, nil)
            var cacheChanged = false

            if self.addCachedObjects(for: samples) {
                cacheChanged = true
            }

            // Deleted samples
            for sample in deleted {
                if self.deleteCachedObject(forSampleUUID: sample.uuid) {
                    cacheChanged = true
                }
            }

            let cachePredicate = NSPredicate(format: "startDate < %@", self.earliestCacheDate as NSDate)
            self.purgeCachedObjects(matching: cachePredicate)

            if cacheChanged || self.lastBasalEndDate == nil {
                self.updateLastBasalEndDate()
            }

            // New data not written by LoopKit (see `MetadataKeyHasLoopKitOrigin`) should be assumed external to what could be fetched as PumpEvent data.
            // That external data could be factored into dose computation with some modification:
            // An example might be supplemental injections in cases of extended exercise periods without a pump
            if cacheChanged {
                NotificationCenter.default.post(name: InsulinDeliveryStore.cacheDidChange, object: self)
            }
        }
    }

    public override var preferredUnit: HKUnit! {
        return super.preferredUnit
    }
}


// MARK: - Adding data
extension InsulinDeliveryStore {
    func addReconciledDoses(_ doses: [DoseEntry], from device: HKDevice?, syncVersion: Int, completion: @escaping (_ result: InsulinDeliveryStoreResult<Bool>) -> Void) {
        let unit = HKUnit.internationalUnit()
        var samples: [HKQuantitySample] = []

        cacheStore.managedObjectContext.performAndWait {
            samples = doses.compactMap { (dose) -> HKQuantitySample? in
                guard let syncIdentifier = dose.syncIdentifier else {
                    log.error("Attempted to add a dose with no syncIdentifier: %{public}@", String(reflecting: dose))
                    return nil
                }

                guard self.cacheStore.managedObjectContext.cachedInsulinDeliveryObjectsWithSyncIdentifier(syncIdentifier, fetchLimit: 1).count == 0 else {
                    log.default("Skipping adding dose due to existing cached syncIdentifier: %{public}@", syncIdentifier)
                    return nil
                }

                return HKQuantitySample(
                    type: insulinType,
                    unit: unit,
                    dose: dose,
                    device: device,
                    syncVersion: syncVersion
                )
            }
        }

        guard samples.count > 0 else {
            completion(.success(true))
            return
        }

        healthStore.save(samples) { (success, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                self.queue.async {
                    if samples.count > 0 {
                        self.addCachedObjects(for: samples)

                        if self.lastBasalEndDate != nil {
                            self.updateLastBasalEndDate()
                        }
                    }

                    completion(.success(true))
                }
            }
        }
    }
}


extension InsulinDeliveryStore {
    /// Returns the end date of the most recent basal sample
    ///
    /// - Parameters:
    ///   - completion: A closure called when the date has been retrieved
    ///   - result: The date
    func getLastBasalEndDate(_ completion: @escaping (_ result: InsulinDeliveryStoreResult<Date>) -> Void) {
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

    /// Returns doses from HealthKit, or the Core Data cache if unavailable
    ///
    /// - Parameters:
    ///   - start: The earliest dose startDate to include
    ///   - end: The latest dose startDate to include
    ///   - isChronological: Whether the doses should be returned in chronological order
    ///   - completion: A closure called when the doses have been retrieved
    ///   - doses: An ordered array of doses
    func getCachedDoses(start: Date, end: Date? = nil, isChronological: Bool = true, _ completion: @escaping (_ doses: [DoseEntry]) -> Void) {
        // If we were asked for an unbounded query, or we're within our cache duration, only return what's in the cache
        guard start > .distantPast, start <= earliestCacheDate else {
            self.queue.async {
                completion(self.getCachedDoseEntries(start: start, end: end, isChronological: isChronological))
            }
            return
        }

        getDoses(start: start, end: end, isChronological: isChronological) { (result) in
            switch result {
            case .success(let doses):
                completion(doses)
            case .failure:
                // Expected when database is inaccessible
                self.queue.async {
                    completion(self.getCachedDoseEntries(start: start, end: end, isChronological: isChronological))
                }
            }
        }
    }
}


// MARK: - HealthKit
extension InsulinDeliveryStore {
    private func getDoses(start: Date, end: Date? = nil, isChronological: Bool = true, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[DoseEntry]>) -> Void) {
        getSamples(start: start, end: end, isChronological: isChronological) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let samples):
                completion(.success(samples.compactMap { $0.dose }))
            }
        }
    }

    private func getSamples(start: Date, end: Date? = nil, isChronological: Bool = true, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[HKQuantitySample]>) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        getSamples(matching: predicate, isChronological: isChronological, completion)
    }

    private func getSamples(matching predicate: NSPredicate, isChronological: Bool, _ completion: @escaping (_ result: InsulinDeliveryStoreResult<[HKQuantitySample]>) -> Void) {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: isChronological)
        let query = HKSampleQuery(sampleType: insulinType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { (query, samples, error) in
            if let error = error {
                completion(.failure(error))
            } else if let samples = samples as? [HKQuantitySample] {
                completion(.success(samples))
            } else {
                assertionFailure("Unknown return configuration from query \(query)")
            }
        }

        healthStore.execute(query)
    }
}


// MARK: - Core Data
extension InsulinDeliveryStore {
    private var earliestCacheDate: Date {
        return currentDate(timeIntervalSinceNow: -cacheLength)
    }

    /// Creates new cached insulin delivery objects from samples if they're not already cached and within the date interval
    ///
    /// - Parameter samples: The samples to cache
    /// - Returns: Whether new cached objects were created
    @discardableResult
    private func addCachedObjects(for samples: [
        HKQuantitySample]) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        var created = false
        cacheStore.managedObjectContext.performAndWait {
            for sample in samples {
                guard
                    sample.startDate.timeIntervalSince(currentDate()) > -self.cacheLength,
                    self.cacheStore.managedObjectContext.cachedInsulinDeliveryObjectsWithUUID(sample.uuid, fetchLimit: 1).count == 0
                else {
                    continue
                }

                let object = CachedInsulinDeliveryObject(context: self.cacheStore.managedObjectContext)
                object.update(from: sample)
                created = true
            }

            if created {
                self.cacheStore.save()
            }
        }

        return created
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

        self.lastBasalEndDate = endDate ?? healthStore.earliestPermittedSampleDate()
    }

    /// Fetches doses from the cache that occur on or after a given start date
    ///
    /// - Parameters:
    ///   - start: The earliest endDate to retrieve
    ///   - end: The latest startDate to retrieve
    ///   - isChronological: Whether the sort order is ascending by start date
    /// - Returns: An ordered array of dose entries
    private func getCachedDoseEntries(start: Date, end: Date? = nil, isChronological: Bool = true) -> [DoseEntry] {
        dispatchPrecondition(condition: .onQueue(queue))

        let startPredicate = NSPredicate(format: "endDate >= %@", start as NSDate)
        let predicate: NSPredicate

        if let end = end {
            let endPredicate = NSPredicate(format: "startDate <= %@", end as NSDate)
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [startPredicate, endPredicate])
        } else {
            predicate = startPredicate
        }

        return getCachedDoseEntries(matching: predicate, isChronological: isChronological)
    }

    /// Fetches doses from the cache that match the given predicate
    ///
    /// - Parameters:
    ///   - predicate: The predicate to apply to the objects
    ///   - isChronological: Whether the sort order is ascending by start date
    /// - Returns: An ordered array of dose entries
    private func getCachedDoseEntries(matching predicate: NSPredicate? = nil, isChronological: Bool = true) -> [DoseEntry] {
        dispatchPrecondition(condition: .onQueue(queue))

        var doses: [DoseEntry] = []

        cacheStore.managedObjectContext.performAndWait {
            let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: isChronological)]

            do {
                let objects = try self.cacheStore.managedObjectContext.fetch(request)
                doses = objects.compactMap { $0.dose }
            } catch let error {
                self.log.error("Error fetching CachedInsulinDeliveryObjects: %{public}@", String(describing: error))
            }
        }

        return doses
    }

    /// Deletes objects from the cache that match the given sample UUID
    ///
    /// - Parameter uuid: The UUID of the sample to delete
    /// - Returns: Whether the deletion was made
    private func deleteCachedObject(forSampleUUID uuid: UUID) -> Bool {
        dispatchPrecondition(condition: .onQueue(queue))

        var deleted = false

        cacheStore.managedObjectContext.performAndWait {
            for object in self.cacheStore.managedObjectContext.cachedInsulinDeliveryObjectsWithUUID(uuid) {

                self.cacheStore.managedObjectContext.delete(object)
                self.log.default("Deleted CachedInsulinDeliveryObject with UUID %{public}@", uuid.uuidString)
                deleted = true
            }

            if deleted {
                self.cacheStore.save()
            }
        }

        return deleted
    }

    private func purgeCachedObjects(matching predicate: NSPredicate) {
        dispatchPrecondition(condition: .onQueue(queue))

        cacheStore.managedObjectContext.performAndWait {
            do {
                let count = try cacheStore.managedObjectContext.purgeObjects(of: CachedInsulinDeliveryObject.self, matching: predicate)
                self.log.default("Purged %d CachedInsulinDeliveryObjects", count)
            } catch let error {
                self.log.error("Unable to purge CachedInsulinDeliveryObjects: %@", String(describing: error))
            }
        }
    }
}


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

            for sample in self.getCachedDoseEntries() {
                report.append(String(describing: sample))
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
