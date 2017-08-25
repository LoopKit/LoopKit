//
//  CarbStore.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


public enum CarbStoreResult<T> {
    case success(T)
    case failure(CarbStore.CarbStoreError)
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
    /// The completion handler must be called in all circumstances, with an array of object IDs that were successfully uploaded or an empty array if the upload failed.
    ///
    /// - parameter carbStore:  The store instance
    /// - parameter entries:    The carb entries
    /// - parameter completion: The closure to execute when the upload attempt has finished. The closure takes a single argument of an array external ids for each entry. If the upload did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [CarbEntry], completion: @escaping (_ uploadedObjects: [String]) -> Void)

    /// Asks the delegate to delete carb entries that were previously uploaded.
    ///
    /// - parameter carbStore:  The store instance
    /// - parameter ids:        The external ids of entries to be deleted
    /// - parameter completion: The closure to execute when the deletion attempt has finished. The closure takes a single argument of an array external ids for each entry. If the deletion did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasDeletedEntries ids: [String], completion: @escaping (_ uploadedObjects: [String]) -> Void)

    /// Asks the delegate to modify carb entries that were previously uploaded.
    ///
    /// - parameter carbStore:  The store instance
    /// - parameter entries:    The carb entries to be uploaded. External id will be set on each carb entry.
    /// - parameter completion: The closure to execute when the modification attempt has finished. The closure takes a single argument of an array external ids for each entry. If the modification did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasModifiedEntries entries: [CarbEntry], completion: @escaping (_ uploadedObjects: [String]) -> Void)
}

extension NSNotification.Name {
    /// Notification posted when carb entries were changed by an external source
    public static let CarbEntriesDidUpdate = NSNotification.Name(rawValue: "com.loudnate.CarbKit.CarbEntriesDidUpdateNotification")
}


/**
 Manages storage, retrieval, and calculation of carbohydrate data.

 There are three tiers of storage:

 * In-memory cache, used for COB and glucose effect calculation
 ```
 0    [2 ✕ DefaultAbsorptionTimes.slow]
 |––––––––––––|
 ```
 * Short-term persistant cache, stored in NSUserDefaults, used to re-populate the in-memory cache if the app is suspended and re-launched while the Health database is protected
 ```
 0    [2 ✕ DefaultAbsorptionTimes.slow]
 |––––––––––––|
 ```
 * HealthKit data, managed by the current application and persisted indefinitely
 ```
 0
 |––––––––––––––––––--->
 ```
 */
public final class CarbStore: HealthKitSampleStore {
    public typealias CarbEntryCacheRawValue = [[String: Any]]

    public typealias DefaultAbsorptionTimes = (fast: TimeInterval, medium: TimeInterval, slow: TimeInterval)

    public static let defaultAbsorptionTimes: DefaultAbsorptionTimes = (fast: TimeInterval(hours: 2), medium: TimeInterval(hours: 3), slow: TimeInterval(hours: 4))

    public enum CarbStoreError: Error {
        case configurationError
        case healthStoreError(Error)
        case unauthorizedError(description: String, recoverySuggestion: String)
        case argumentError(description: String, recoverySuggestion: String)
        case fetchError(description: String, recoverySuggestion: String?)
    }

    private let carbType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)!

    /// All the sample types we need permission to read.
    /// Eventually, we may want to consider fat, protein, and other factors to estimate carb absorption.
    public override var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: carbType)
    }

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: carbType)
    }

    /// The preferred unit. iOS currently only supports grams for dietary carbohydrates.
    public let preferredUnit = HKUnit.gram()

    /// Carbohydrate-to-insulin ratio
    public var carbRatioSchedule: CarbRatioSchedule?

    /// A trio of default carbohydrate absorption times. Defaults to 2, 3, and 4 hours.
    public var defaultAbsorptionTimes: DefaultAbsorptionTimes {
        didSet {
            // If maximumAbsorptionTimeInterval increases, reset our anchored queries
            if defaultAbsorptionTimes.slow > oldValue.slow {
                createQueries()
            }
        }
    }

    /// Insulin-to-glucose sensitivity
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?

    /// The expected delay in the appearance of glucose effects, accounting for both digestion and sensor lag
    public var delay: TimeInterval = TimeInterval(minutes: 10)

    /// The interval between effect values to use for the calculated timelines.
    private(set) public var delta: TimeInterval = TimeInterval(minutes: 5)

    /// The factor by which the entered absorption time can be extended to accomodate slower-than-expected absorption
    public var absorptionTimeOverrun: Double = 1.5

    /// The longest expected absorption time interval for carbohydrates. Defaults to 8 hours.
    public var maximumAbsorptionTimeInterval: TimeInterval {
        return defaultAbsorptionTimes.slow * 2
    }

    public weak var delegate: CarbStoreDelegate?

    public weak var syncDelegate: CarbStoreSyncDelegate?

    // Tracks modified carbEntries that need to modified in the external store
    private var modifiedCarbEntries: Set<StoredCarbEntry> {
        didSet {
            UserDefaults.standard.modifiedCarbEntries = Array<StoredCarbEntry>(self.modifiedCarbEntries)
        }
    }

    // Track deleted carbEntry ids that need to be delete from the external store
    private var deletedCarbEntryIDs: Set<String> {
        didSet {
            UserDefaults.standard.deletedCarbEntryIds = Array<String>(self.deletedCarbEntryIDs)
        }
    }


    /**
     Initializes a new instance of the store.
     
     `nil` is returned if HealthKit is not available on the current device.

     - returns: A new instance of the store
     */
    public init?(healthStore: HKHealthStore = HKHealthStore(), defaultAbsorptionTimes: DefaultAbsorptionTimes = defaultAbsorptionTimes, carbRatioSchedule: CarbRatioSchedule? = nil, insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil) {
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
        self.carbRatioSchedule = carbRatioSchedule
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbEntryCache = Set(UserDefaults.standard.carbEntryCache ?? [])
        self.modifiedCarbEntries = Set(UserDefaults.standard.modifiedCarbEntries ?? [])
        self.deletedCarbEntryIDs = Set(UserDefaults.standard.deletedCarbEntryIds ?? [])

        super.init(healthStore: healthStore)

        if !authorizationRequired {
            createQueries()
        }
    }

    public override func authorize(_ completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        super.authorize { (success: Bool, error: Error?) -> Void in
            if success {
                self.createQueries()
            }

            completion(success, error)
        }
    }

    // MARK: - Query

    /// All active observer queries
    private var observerQueries: [HKObserverQuery] = []

    /// The last-retreived anchor for each anchored object query, by sample type
    private var queryAnchors: [HKObjectType: HKQueryAnchor] = [:]

    private func createQueries() {
        // Clear and reset query state
        for query in observerQueries {
            healthStore.stop(query)
        }

        observerQueries = []
        queryAnchors = [:]

        let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maximumAbsorptionTimeInterval), end: nil)
        for type in readTypes {
            let observerQuery = HKObserverQuery(sampleType: type, predicate: predicate) { [unowned self] (query, completionHandler, error) -> Void in

                if let error = error {
                    self.delegate?.carbStore(self, didError: .healthStoreError(error))
                } else {
                    self.dataAccessQueue.async {
                        let anchoredObjectQuery = HKAnchoredObjectQuery(
                            type: type,
                            predicate: predicate,
                            anchor: self.queryAnchors[type],
                            limit: HKObjectQueryNoLimit,
                            resultsHandler: self.processResultsFromAnchoredQuery
                        )

                        self.healthStore.execute(anchoredObjectQuery)
                    }
                }

                completionHandler()
            }

            healthStore.execute(observerQuery)
            observerQueries.append(observerQuery)
        }
    }

    deinit {
        for query in observerQueries {
            healthStore.stop(query)
        }
    }

    // MARK: - Background management

    /// Whether background delivery of new data is enabled
    public private(set) var isBackgroundDeliveryEnabled = false

    /**
     Enables the background delivery of updates to carbohydrate data from the Health database.
     
     This is only necessary if carbohydrate data is used in a long-running task (like automated dosing) and new entries are expected from other apps or input sources.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter enabled:    Whether to enable or disable background delivery
     - parameter completion: A closure called after the background delivery preference is changed. The closure takes two arguments:
        - success: Whether the background delivery preference was successfully updated
        - error:   An error object explaining why the preference failed to update
     */
    public func setBackgroundDeliveryEnabled(_ enabled: Bool, completion: @escaping (_ success: Bool, _ error: CarbStoreError?) -> Void) {
        self.dataAccessQueue.async { () -> Void in
            let oldValue = self.isBackgroundDeliveryEnabled
            self.isBackgroundDeliveryEnabled = enabled

            switch (oldValue, enabled) {
            case (false, true):
                let group = DispatchGroup()
                var lastError: CarbStoreError?

                for type in self.readTypes {
                    group.enter()
                    self.healthStore.enableBackgroundDelivery(for: type, frequency: .immediate, withCompletion: { [unowned self] (enabled, error) -> Void in
                        if !enabled {
                            self.isBackgroundDeliveryEnabled = oldValue

                            if let error = error {
                                lastError = .healthStoreError(error)
                            }
                        }

                        group.leave()
                    })
                }

                _ = group.wait(timeout: .distantFuture)
                completion(enabled == self.isBackgroundDeliveryEnabled, lastError)
            case (true, false):
                let group = DispatchGroup()
                var lastError: CarbStoreError?

                for type in self.readTypes {
                    group.enter()
                    self.healthStore.disableBackgroundDelivery(for: type, withCompletion: { [unowned self] (disabled, error) -> Void in
                        if !disabled {
                            self.isBackgroundDeliveryEnabled = oldValue

                            if let error = error {
                                lastError = .healthStoreError(error)
                            }
                        }

                        group.leave()
                    })
                }

                _ = group.wait(timeout: .distantFuture)
                completion(enabled == self.isBackgroundDeliveryEnabled, lastError)
            default:
                completion(true, nil)
            }
        }
    }


    // MARK: - Data fetching

    private func processResultsFromAnchoredQuery(_ query: HKAnchoredObjectQuery, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, anchor: HKQueryAnchor?, error: Error?) {

        if let error = error {
            self.delegate?.carbStore(self, didError: .healthStoreError(error))
            return
        }

        dataAccessQueue.async {
            let cutoffDate = Date(timeIntervalSinceNow: -self.maximumAbsorptionTimeInterval)
            var notificationRequired = false

            // Append the new samples
            if let samples = newSamples as? [HKQuantitySample] {
                for sample in samples {
                    let entry = StoredCarbEntry(sample: sample)

                    if !self.carbEntryCache.contains(entry) {
                        notificationRequired = true
                        self.carbEntryCache.insert(entry)
                    }
                }
            }

            // Remove deleted samples
            for sample in deletedSamples ?? [] {
                if let index = self.carbEntryCache.index(where: { $0.sampleUUID == sample.uuid }) {
                    self.carbEntryCache.remove(at: index)
                    notificationRequired = true
                }
            }

            // Filter old samples
            self.carbEntryCache = Set(self.carbEntryCache.filter { $0.startDate >= cutoffDate })

            // Update the anchor
            self.queryAnchors[query.objectType!] = anchor

            // Notify listeners only if a meaningful change was made
            if notificationRequired {
                self.persistCarbEntryCache()
                self.syncExternalDB()

                NotificationCenter.default.post(name: .CarbEntriesDidUpdate, object: self)
            }
        }
    }

    private var carbEntryCache: Set<StoredCarbEntry>

    private var dataAccessQueue: DispatchQueue = DispatchQueue(label: "com.loudnate.CarbKit.dataAccessQueue")

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
    private func getCachedCarbSamples(start: Date, end: Date? = nil, completion: @escaping (_ samples: [StoredCarbEntry]) -> Void) {
        getCarbSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                completion(samples)
            case .failure:
                completion(self.carbEntryCache.filterDateRange(start, end).sorted(by: <))
            }
        }
    }

    /**
     Retrieves recent carb entries from HealthKit, or from the short-term cache if HealthKit is inaccessible.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of entries to retrieve. Defaults to the earlier of the current date less `maximumAbsorptionTimeInterval`, or the previous midnight in the current time zone.
     - parameter endDate:        The latest date of entries to retrieve. Defaults to the distance future.
     - parameter resultsHandler: A closure called once the entries have been retrieved. The closure takes two arguments:
        - entries: The retrieved entries
        - error:   An error object explaning why the retrieval failed
     */
    @available(*, deprecated, message: "Use getCarbEntries(start:end:completion:) instead")
    public func getRecentCarbEntries(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ entries: [CarbEntry], _ error: Error?) -> Void) {
        getCachedCarbSamples(start: startDate ?? Date(timeIntervalSinceNow: -maximumAbsorptionTimeInterval), end: endDate) { (entries) in
            resultsHandler(entries, nil)
        }
    }

    /// Retrieves carb entries from HealthKit within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure calld once the values have been retrieved
    ///   - result: An array of carb entries, in chronological order by startDate
    public func getCarbEntries(start: Date, end: Date? = nil, completion: @escaping (_ result: CarbStoreResult<[CarbEntry]>) -> Void) {
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
        completion: @escaping (_ result: CarbStoreResult<[CarbStatus]>) -> Void
    ) {
        getCarbSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                let status = samples.map(
                    to: effectVelocities ?? [],
                    carbRatio: self.carbRatioSchedule,
                    insulinSensitivity: self.insulinSensitivitySchedule,
                    absorptionTimeOverrun: self.absorptionTimeOverrun,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay
                )

                completion(.success(status))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Retrieves carb entries from either HealthKit or the in-memory cache.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - values: An array of carb entries, in chronological order by start date
    public func getCachedCarbEntries(start: Date, end: Date? = nil, completion: @escaping (_ entries: [CarbEntry]) -> Void) {
        getCachedCarbSamples(start: start, end: end) { (entries) in
            completion(entries)
        }
    }

    public func addCarbEntry(_ entry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ entry: CarbEntry?, _ error: CarbStoreError?) -> Void) {
        addCarbEntryInternal(entry) { (success, entry, error) in
            resultHandler(success, entry, error)
            self.syncExternalDB()
        }
    }

    private func addCarbEntryInternal(_ entry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ entry: StoredCarbEntry?, _ error: CarbStoreError?) -> Void) {
        let quantity = entry.quantity
        var metadata = [String: Any]()

        if let absorptionTime = entry.absorptionTime {
            metadata[MetadataKeyAbsorptionTimeMinutes] = absorptionTime
        }

        if let foodType = entry.foodType {
            metadata[HKMetadataKeyFoodType] = foodType
        }

        metadata[HKMetadataKeyExternalUUID] = entry.externalID

        let carbs = HKQuantitySample(type: carbType, quantity: quantity, start: entry.startDate, end: entry.startDate, device: nil, metadata: metadata)
        let storedObject = StoredCarbEntry(sample: carbs, createdByCurrentApp: true)

        dataAccessQueue.async {
            self.carbEntryCache.insert(storedObject)

            self.healthStore.save(carbs, withCompletion: { (completed, error) -> Void in
                self.dataAccessQueue.async {
                    if !completed {
                        self.carbEntryCache.remove(storedObject)
                    } else {
                        self.persistCarbEntryCache()
                    }

                    resultHandler(
                        completed,
                        storedObject,
                        error != nil ? .healthStoreError(error!) : nil
                    )
                }
            }) 
        }
    }

    public func replaceCarbEntry(_ oldEntry: CarbEntry, withEntry newEntry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ entry: CarbEntry?, _ error: CarbStoreError?) -> Void) {
        replaceCarbEntryInternal(oldEntry, withEntry: newEntry) { (success, entry, error) in
            if let entry = entry, success, self.syncDelegate != nil {
                self.modifiedCarbEntries.insert(entry)
                self.syncExternalDB()
            }
            resultHandler(success, entry, error)
        }
    }

    private func replaceCarbEntryInternal(_ oldEntry: CarbEntry, withEntry newEntry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ entry: StoredCarbEntry?, _ error: CarbStoreError?) -> Void) {
        deleteCarbEntryInternal(oldEntry) { (completed, error) -> Void in
            if let error = error {
                resultHandler(false, nil, error)
            } else {
                self.addCarbEntryInternal(newEntry, resultHandler: resultHandler)
            }
        }
    }

    public func deleteCarbEntry(_ entry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ error: CarbStoreError?) -> Void) {
        deleteCarbEntryInternal(entry) { (success, error) in
            if let externalID = entry.externalID, success, self.syncDelegate != nil {
                self.deletedCarbEntryIDs.insert(externalID)
                self.syncExternalDB()
            }
            resultHandler(success, error)
        }
    }

    private func deleteCarbEntryInternal(_ entry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ error: CarbStoreError?) -> Void) {
        if let entry = entry as? StoredCarbEntry {
            if entry.createdByCurrentApp {
                let predicate = HKQuery.predicateForObjects(with: [entry.sampleUUID])
                let query = HKSampleQuery(sampleType: carbType, predicate: predicate, limit: 1, sortDescriptors: nil, resultsHandler: { (_, objects, error) -> Void in
                    if let error = error {
                        resultHandler(false, .healthStoreError(error))
                    } else if let objects = objects {
                        self.dataAccessQueue.async {
                            self.carbEntryCache.remove(entry)

                            self.healthStore.delete(objects, withCompletion: { (success, error) in
                                self.dataAccessQueue.async {
                                    if !success {
                                        self.carbEntryCache.insert(entry)
                                    } else {
                                        self.persistCarbEntryCache()
                                    }

                                    resultHandler(success, error != nil ? .healthStoreError(error!) : nil)
                                }
                            }) 
                        }
                    }
                })

                healthStore.execute(query)
            } else {
                resultHandler(
                    false,
                    .unauthorizedError(
                        description: NSLocalizedString("com.loudnate.CarbKit.deleteCarbEntryUnownedErrorDescription", tableName: "CarbKit", value: "Authorization Denied", comment: "The description of an error returned when attempting to delete a sample not shared by the current app"),
                        recoverySuggestion: NSLocalizedString("com.loudnate.carbKit.sharingDeniedErrorRecoverySuggestion", tableName: "CarbKit", value: "This sample can be deleted from the Health app", comment: "The error recovery suggestion when attempting to delete a sample not shared by the current app")
                    )
                )
            }
        } else {
            resultHandler(
                false,
                .argumentError(
                    description: NSLocalizedString("com.loudnate.CarbKit.deleteCarbEntryInvalid", tableName: "CarbKit", value: "Invalid Entry", comment: "The description of an error returned when attempting to delete a non-HealthKit sample"),
                    recoverySuggestion: NSLocalizedString("com.loudnate.carbKit.sharingDeniedErrorRecoverySuggestion", tableName: "CarbKit", value: "This object is not saved in the Health database and therefore cannot be deleted", comment: "The error recovery suggestion when attempting to delete a non-HealthKit sample")
                )
            )
        }
    }

    /**
     Persists the in-memory cache to NSUserDefaults.
     
     *This method should only be called from the `dataAccessQueue`*
     */
    private func persistCarbEntryCache() {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))
        UserDefaults.standard.carbEntryCache = Array<StoredCarbEntry>(carbEntryCache)
    }

    // MARK: - Math

    @available(*, deprecated, message: "Use carbsOnBoard(at:completion:) instead")
    public func carbsOnBoardAtDate(_ date: Date, resultHandler: @escaping (_ value: CarbValue?, _ error: Error?) -> Void) {
        carbsOnBoard(at: date) { (result) in
            switch result {
            case .success(let value):
                resultHandler(value, nil)
            case .failure(let error):
                resultHandler(nil, error)
            }
        }
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
            guard let value = values.closestPriorToDate(date) else {
                completion(.failure(.fetchError(description: "No values found", recoverySuggestion: "Ensure carb data exists for the specified date")))
                return
            }
            completion(.success(value))
        }
    }

    /// Retrieves a timeline of unabsorbed carbohyrdates.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - startDate: The earliest date of values to retrieve. The default, and earliest supported value, is the previous midnight in the current time zone.
    ///   - endDate: The latest date of values to retrieve. Defaults to the distant future.
    ///   - completion: A closure called once the values have been retrieved.
    ///   - values: The retrieved values
    ///   - error: Error is always nil
    @available(*, deprecated, message: "Use getCarbsOnBoardValues(start:end:completion:) instead")
    public func getCarbsOnBoardValues(
        startDate: Date? = nil,
        endDate: Date? = nil,
        completion: @escaping (_ values: [CarbValue], _ error: Error?) -> Void) {
        getCarbsOnBoardValues(start: startDate ?? Date(), end: endDate) { (values) in
            completion(values, nil)
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

            if let velocities = effectVelocities, let carbRatioSchedule = self.carbRatioSchedule, let insulinSensitivitySchedule = self.insulinSensitivitySchedule {
                carbsOnBoard = samples.map(
                    to: velocities,
                    carbRatio: carbRatioSchedule,
                    insulinSensitivity: insulinSensitivitySchedule,
                    absorptionTimeOverrun: self.absorptionTimeOverrun,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay
                ).dynamicCarbsOnBoard(
                    from: start,
                    to: end,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay,
                    delta: self.delta
                )
            } else {
                carbsOnBoard = samples.carbsOnBoard(
                    from: start,
                    to: end,
                    defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                    delay: self.delay,
                    delta: self.delta
                )
            }

            completion(carbsOnBoard)
        }
    }

    /**
     Retrieves a timeline of effect on blood glucose from carbohydrates

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of effects to retrieve. The earliest supported value is the previous midnight in the current time zone.
     - parameter endDate:       The latest date of effects to retrieve. Defaults to the distant future.
     - parameter resultHandler: A closure called once the effects have been retrieved. The closure takes two arguments:
        - effects: The retrieved timeline of effects
        - error:   An error object explaining why the retrieval failed
     */
    @available(*, deprecated, message: "Use getGlucoseEffects(start:end:completion:) instead")
    public func getGlucoseEffects(
        startDate: Date,
        endDate: Date? = nil,
        resultHandler: @escaping (_ effects: [GlucoseEffect], _ error: CarbStoreError?) -> Void)
    {
        getGlucoseEffects(start: startDate, end: endDate) { (result) in
            switch result {
            case .success(let effects):
                resultHandler(effects, nil)
            case .failure(let error):
                resultHandler([], error)
            }
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
        dataAccessQueue.async {
            guard let carbRatioSchedule = self.carbRatioSchedule, let insulinSensitivitySchedule = self.insulinSensitivitySchedule else {
                completion(.failure(.configurationError))
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
                        delay: delay
                    ).dynamicGlucoseEffects(
                        from: start,
                        to: end,
                        carbRatios: carbRatioSchedule,
                        insulinSensitivities: insulinSensitivitySchedule,
                        defaultAbsorptionTime: defaultAbsorptionTimes.medium,
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
                        delay: delay,
                        delta: delta
                    )
                }

                completion(.success(effects))
            }
        }
    }

    /**
     Retrieves the total number of recorded carbohydrates for the specified period.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of entries to include. Defaults to the earlier of the current date less `maximumAbsorptionTimeInterval`, or the previous midnight in the current time zone.
     - parameter endDate:       The latest date of entries to include. Defaults to the distant future.
     - parameter resultHandler: A closure called once the value has been retrieved. The closure takes two arguments:
        - value: The retrieved value
        - error: An error object explaining why the retrieval failed
     */
    @available(*, deprecated, message: "Use getTotalCarbs(since:completion:)")
    public func getTotalRecentCarbValue(startDate: Date? = nil, endDate: Date? = nil, resultHandler: @escaping (_ value: CarbValue?, _ error: Error?) -> Void) {
        getTotalCarbs(since: Calendar.current.startOfDay(for: Date())) { (result) in
            switch result {
            case .success(let samples):
                resultHandler(samples, nil)
            case .failure(let error):
                resultHandler(nil, error)
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
                    quantity: HKQuantity(unit: .gram(), doubleValue: 0)
                )

                completion(.success(total))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        func entryReport(_ entry: CarbEntry) -> String {
            return "* \(entry.startDate), \(entry.quantity), \(entry.absorptionTime ?? self.defaultAbsorptionTimes.medium), \(entry.createdByCurrentApp ? "" : "External")"
        }

        var report: [String] = [
            "## CarbStore",
            "",
            "* carbRatioSchedule: \(carbRatioSchedule?.debugDescription ?? "")",
            "* defaultAbsorptionTimes: \(defaultAbsorptionTimes)",
            "* insulinSensitivitySchedule: \(insulinSensitivitySchedule?.debugDescription ?? "")",
            "* delay: \(delay)",
            "* authorizationRequired: \(authorizationRequired)",
            "* isBackgroundDeliveryEnabled: \(isBackgroundDeliveryEnabled)",
            "",
            "### carbEntryCache"
        ]

        for entry in carbEntryCache {
            report.append(entryReport(entry))
        }

        completionHandler(report.joined(separator: "\n"))
    }

    private func syncExternalDB() {
        dataAccessQueue.async {
            let entriesToUpload: [CarbEntry] = self.carbEntryCache.filter { !$0.isUploaded }
            if entriesToUpload.count > 0 {
                self.syncDelegate?.carbStore(self, hasEntriesNeedingUpload: entriesToUpload) { (externalIDs) in
                    if externalIDs.count == entriesToUpload.count {
                        for (entry, id) in zip(entriesToUpload, externalIDs) {
                            let newEntry = NewCarbEntry(
                                quantity: entry.quantity,
                                startDate: entry.startDate,
                                foodType: entry.foodType,
                                absorptionTime: entry.absorptionTime,
                                isUploaded: true,
                                externalID: id
                            )
                            self.replaceCarbEntryInternal(entry, withEntry: newEntry) { (replaced, entry, error) in
                                if let error = error {
                                    self.delegate?.carbStore(self, didError: .healthStoreError(error))
                                }
                            }
                        }
                    }
                }
            }

            if self.modifiedCarbEntries.count > 0 {
                self.syncDelegate?.carbStore(self, hasModifiedEntries: Array<StoredCarbEntry>(self.modifiedCarbEntries)) { (uploadedEntries) in
                    if uploadedEntries.count == self.modifiedCarbEntries.count {
                        self.modifiedCarbEntries = []
                    }
                }
            }

            if self.deletedCarbEntryIDs.count > 0 {
                self.syncDelegate?.carbStore(self, hasDeletedEntries: Array<String>(self.deletedCarbEntryIDs)) { (ids) in
                    if ids.count == self.deletedCarbEntryIDs.count {
                        self.deletedCarbEntryIDs = []
                    }
                }
            }
        }
    }
}
