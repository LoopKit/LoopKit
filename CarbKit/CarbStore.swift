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


public protocol CarbStoreDelegate: class {

    /// Informs the delegate that an internal error occurred
    ///
    /// - parameter carbStore: The carb store
    /// - parameter error:     The error describing the issue
    ///
    /// - returns: <#return value description#>
    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError)
}

public protocol CarbStoreSyncDelegate: class {

    /// Asks the delegate to upload recently-added carb entries not yet marked as uploaded.
    ///
    /// The completion handler must be called in all circumstances, with an array of object IDs that were successfully uploaded or an empty array if the upload failed.
    ///
    /// - parameter carbStore:         The store instance
    /// - parameter entries:           The carb entries
    /// - parameter completionHandler: The closure to execute when the upload attempt has finished. The closure takes a single argument of an array external ids for each entry. If the upload did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [CarbEntry], withCompletion completionHandler: @escaping (_ uploadedObjects: [String]) -> Void)

    /// Asks the delegate to delete carb entries that were previously uploaded.
    ///
    /// - parameter carbStore:         The store instance
    /// - parameter ids:               The external ids of entries to be deleted
    /// - parameter completionHandler: The closure to execute when the deletion attempt has finished. The closure takes a single argument of an array external ids for each entry. If the deletion did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasDeletedEntries ids: [String], withCompletion completionHandler: @escaping (_ uploadedObjects: [String]) -> Void)

    /// Asks the delegate to modify carb entries that were previously uploaded.
    ///
    /// - parameter carbStore:         The store instance
    /// - parameter entries:           The carb entries to be uploaded. External id will be set on each carb entry.
    /// - parameter completionHandler: The closure to execute when the modification attempt has finished. The closure takes a single argument of an array external ids for each entry. If the modification did not succeed, call the closure with an empty array.
    func carbStore(_ carbStore: CarbStore, hasModifiedEntries entries: [CarbEntry], withCompletion completionHandler: @escaping (_ uploadedObjects: [String]) -> Void)
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
 0    [2 ✕ maximumAbsorptionTimeInterval]
 |––––––––––––|
 ```
 * Short-term persistant cache, stored in NSUserDefaults, used to re-populate the in-memory cache if the app is suspended and re-launched while the Health database is protected
 ```
 0    [2 ✕ maximumAbsorptionTimeInterval]
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

    public enum CarbStoreError: Error {
        case configurationError
        case healthStoreError(Error)
        case unauthorizedError(description: String, recoverySuggestion: String)
        case argumentError(description: String, recoverySuggestion: String)
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
    public private(set) var preferredUnit: HKUnit = HKUnit.gram()

    /// Carbohydrate-to-insulin ratio
    public var carbRatioSchedule: CarbRatioSchedule? {
        didSet {
            dataAccessQueue.async {
                self.clearCalculationCache()
            }
        }
    }

    /// A trio of default carbohydrate absorption times. Defaults to 2, 3, and 4 hours.
    public let defaultAbsorptionTimes: DefaultAbsorptionTimes

    /// Insulin-to-glucose sensitivity
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        didSet {
            dataAccessQueue.async {
                self.clearCalculationCache()
            }
        }
    }

    /// The expected delay in the appearance of glucose effects, accounting for both digestion and sensor lag
    public var delay: TimeInterval = TimeInterval(minutes: 10) {
        didSet {
            dataAccessQueue.async {
                self.clearCalculationCache()
            }
        }
    }

    /// The interval between effect values to use for the calculated timelines.
    private(set) public var delta: TimeInterval = TimeInterval(minutes: 5) {
        didSet {
            dataAccessQueue.async {
                self.clearCalculationCache()
            }
        }
    }

    /// The longest expected absorption time interval for carbohydrates. Defaults to 8 hours.
    private let maximumAbsorptionTimeInterval: TimeInterval

    public weak var delegate: CarbStoreDelegate?

    public weak var syncDelegate: CarbStoreSyncDelegate?

    // Tracks modified carbEntries that need to modified in the external store
    private var modifiedCarbEntries: Set<StoredCarbEntry>

    // Track deleted carbEntry ids that need to be delete from the external store
    private var deletedCarbEntryIds: Set<String>


    /**
     Initializes a new instance of the store.
     
     `nil` is returned if HealthKit is not available on the current device.

     - returns: A new instance of the store
     */
    public init?(defaultAbsorptionTimes: DefaultAbsorptionTimes = (TimeInterval(hours: 2), TimeInterval(hours: 3), TimeInterval(hours: 4)), carbRatioSchedule: CarbRatioSchedule? = nil, insulinSensitivitySchedule :InsulinSensitivitySchedule? = nil) {
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
        self.maximumAbsorptionTimeInterval = defaultAbsorptionTimes.slow * 2
        self.carbRatioSchedule = carbRatioSchedule
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbEntryCache = Set(UserDefaults.standard.carbEntryCache ?? [])
        self.modifiedCarbEntries = Set(UserDefaults.standard.modifiedCarbEntries ?? [])
        self.deletedCarbEntryIds = Set(UserDefaults.standard.deletedCarbEntryIds ?? [])

        super.init()

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

    /// All active anchored object queries, by sample type
    private var anchoredObjectQueries: [HKSampleType: HKAnchoredObjectQuery] = [:]

    /// The last-retreived anchor for each anchored object query, by sample type
    private var queryAnchors: [HKObjectType: HKQueryAnchor] = [:]

    private func createQueries() {
        let predicate = recentSamplesPredicate()

        for type in readTypes {
            let observerQuery = HKObserverQuery(sampleType: type, predicate: predicate, updateHandler: { [unowned self] (query, completionHandler, error) -> Void in

                if let error = error {
                    self.delegate?.carbStore(self, didError: .healthStoreError(error))
                } else {
                    self.dataAccessQueue.async {
                        if self.anchoredObjectQueries[type] == nil {
                            let anchoredObjectQuery = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: self.queryAnchors[type], limit: Int(HKObjectQueryNoLimit), resultsHandler: self.processResultsFromAnchoredQuery)
                            anchoredObjectQuery.updateHandler = self.processResultsFromAnchoredQuery

                            self.anchoredObjectQueries[type] = anchoredObjectQuery
                            self.healthStore.execute(anchoredObjectQuery)
                        }
                    }
                }

                completionHandler()
            })

            healthStore.execute(observerQuery)
            observerQueries.append(observerQuery)
        }
    }

    deinit {
        for query in observerQueries {
            healthStore.stop(query)
        }

        for query in anchoredObjectQueries.values {
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
            // Prune the sample data based on the startDate and deletedSamples array
            let cutoffDate = Date(timeIntervalSinceNow: -self.maximumAbsorptionTimeInterval)
            var notificationRequired = false

            self.carbEntryCache = Set(self.carbEntryCache.filter { (entry) in
                if entry.startDate < cutoffDate {
                    return false
                } else if let deletedSamples = deletedSamples, deletedSamples.contains(where: { $0.uuid == entry.sampleUUID as UUID }) {
                    notificationRequired = true
                    return false
                } else {
                    return true
                }
            })

            // Append the new samples
            if let samples = newSamples as? [HKQuantitySample] {
                for sample in samples {
                    let entry = StoredCarbEntry(sample: sample)

                    if entry.startDate >= cutoffDate && !self.carbEntryCache.contains(entry) {
                        notificationRequired = true
                        self.carbEntryCache.insert(entry)
                    }
                }
            }

            // Update the anchor
            self.queryAnchors[query.objectType!] = anchor

            // Notify listeners only if a meaningful change was made
            if notificationRequired {
                self.clearCalculationCache()
                self.persistCarbEntryCache()
                self.syncExternalDB()

                NotificationCenter.default.post(name: .CarbEntriesDidUpdate, object: self)
            }
        }
    }

    private var carbEntryCache: Set<StoredCarbEntry>

    private var dataAccessQueue: DispatchQueue = DispatchQueue(label: "com.loudnate.CarbKit.dataAccessQueue", attributes: [])

    private var recentSamplesStartDate: Date {
        let calendar = Calendar.current

        return min(calendar.startOfDay(for: Date()), Date(timeIntervalSinceNow: -maximumAbsorptionTimeInterval - TimeInterval(minutes: 5)))
    }

    private func recentSamplesPredicate(startDate: Date? = nil, endDate: Date? = nil) -> NSPredicate {
        return HKQuery.predicateForSamples(withStart: startDate ?? recentSamplesStartDate, end: endDate ?? Date.distantFuture, options: [.strictStartDate])
    }

    private func getCachedCarbSamples(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ entries: [StoredCarbEntry], _ error: CarbStoreError?) -> Void) {
        dataAccessQueue.async {
            let entries = self.carbEntryCache.filterDateRange(startDate, endDate)
            resultsHandler(entries, nil)
        }
    }

    private func getRecentCarbSamples(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ entries: [StoredCarbEntry], _ error: CarbStoreError?) -> Void) {
        if UIApplication.shared.isProtectedDataAvailable {
            let predicate = recentSamplesPredicate(startDate: startDate, endDate: endDate)
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

            let query = HKSampleQuery(sampleType: carbType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

                if let error = error as? NSError, error.code == HKError.errorDatabaseInaccessible.rawValue {
                    self.getCachedCarbSamples(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
                } else {
                    resultsHandler(
                        (samples as? [HKQuantitySample])?.map {
                            StoredCarbEntry(sample: $0)
                            } ?? [],
                        error != nil ? .healthStoreError(error!) : nil
                    )
                }
            }

            healthStore.execute(query)
        } else {
            getCachedCarbSamples(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
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
    public func getRecentCarbEntries(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ entries: [CarbEntry], _ error: Error?) -> Void) {
        getRecentCarbSamples(startDate: startDate, endDate: endDate) { (entries, error) -> Void in
            resultsHandler(entries.map { $0 }, error)
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

        metadata[HKMetadataKeyExternalUUID] = entry.externalId

        let carbs = HKQuantitySample(type: carbType, quantity: quantity, start: entry.startDate, end: entry.startDate, device: nil, metadata: metadata)
        let storedObject = StoredCarbEntry(sample: carbs, createdByCurrentApp: true)

        dataAccessQueue.async {
            self.carbEntryCache.insert(storedObject)

            self.healthStore.save(carbs, withCompletion: { (completed, error) -> Void in
                self.dataAccessQueue.async {
                    if !completed {
                        self.carbEntryCache.remove(storedObject)
                    } else {
                        self.clearCalculationCache()
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
                self.persistModifiedCarbEntries()
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
            if let externalId = entry.externalId, success, self.syncDelegate != nil {
                self.deletedCarbEntryIds.insert(externalId)
                self.persistDeletedCarbEntryIds()
                self.syncExternalDB()
            }
            resultHandler(success, error)
        }
    }

    private func deleteCarbEntryInternal(_ entry: CarbEntry, resultHandler: @escaping (_ success: Bool, _ error: CarbStoreError?) -> Void) {
        if let entry = entry as? StoredCarbEntry {
            if entry.createdByCurrentApp {
                let predicate = HKQuery.predicateForObjects(with: [entry.sampleUUID as UUID])
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
                                        self.clearCalculationCache()
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
        UserDefaults.standard.carbEntryCache = Array<StoredCarbEntry>(carbEntryCache)
    }

    private func persistModifiedCarbEntries() {
        UserDefaults.standard.modifiedCarbEntries = Array<StoredCarbEntry>(self.modifiedCarbEntries)
    }

    private func persistDeletedCarbEntryIds() {
        UserDefaults.standard.deletedCarbEntryIds = Array<String>(self.deletedCarbEntryIds)
    }

    // MARK: - Math

    /**
    *This method should only be called from the `dataAccessQueue`*
    */
    private func clearCalculationCache() {
        carbsOnBoardCache = nil
        glucoseEffectsCache = nil
    }

    private var carbsOnBoardCache: [CarbValue]?

    private var glucoseEffectsCache: [GlucoseEffect]?

    public func carbsOnBoardAtDate(_ date: Date, resultHandler: @escaping (_ value: CarbValue?, _ error: Error?) -> Void) {
        getCarbsOnBoardValues { (values, error) -> Void in
            resultHandler(values.closestPriorToDate(date), error)
        }
    }

    /**
     Retrieves a timeline of unabsorbed carbohyrdates.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of values to retrieve. The default, and earliest supported value, is the previous midnight in the current time zone.
     - parameter endDate:       The latest date of values to retrieve. Defaults to the distant future.
     - parameter resultHandler: A closure called once the values have been retrieved. The closure takes two arguments:
        - values: The retrieved values
        - error:  An error object explaining why the retrieval failed
     */
    public func getCarbsOnBoardValues(
        startDate: Date? = nil,
        endDate: Date? = nil,
        resultHandler: @escaping (_ values: [CarbValue], _ error: Error?) -> Void) {

        dataAccessQueue.async { [unowned self] in
            if self.carbsOnBoardCache == nil {
                self.getCachedCarbSamples { (entries, error) -> Void in
                    if error == nil {
                        self.carbsOnBoardCache = CarbMath.carbsOnBoardForCarbEntries(entries,
                            defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                            delay: self.delay,
                            delta: self.delta
                        )
                    }

                    resultHandler(self.carbsOnBoardCache?.filterDateRange(startDate, endDate).map { $0 } ?? [], error)
                }
            } else {
                resultHandler(self.carbsOnBoardCache?.filterDateRange(startDate, endDate) ?? [], nil)
            }
        }
    }

    /**
     Retrieves a timeline of effect on blood glucose from carbohydrates

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of effects to retrieve. The default, and earliest supported value, is the previous midnight in the current time zone.
     - parameter endDate:       The latest date of effects to retrieve. Defaults to the distant future.
     - parameter resultHandler: A closure called once the effects have been retrieved. The closure takes two arguments:
        - effects: The retrieved timeline of effects
        - error:   An error object explaining why the retrieval failed
     */
    public func getGlucoseEffects(
        startDate: Date? = nil,
        endDate: Date? = nil,
        resultHandler: @escaping (_ effects: [GlucoseEffect], _ error: CarbStoreError?) -> Void) {

        dataAccessQueue.async {
            if self.glucoseEffectsCache == nil {
                if let carbRatioSchedule = self.carbRatioSchedule, let insulinSensitivitySchedule = self.insulinSensitivitySchedule {
                    self.getCachedCarbSamples { (entries, error) -> Void in
                        if error == nil {
                            self.glucoseEffectsCache = CarbMath.glucoseEffectsForCarbEntries(entries,
                                carbRatios: carbRatioSchedule,
                                insulinSensitivities: insulinSensitivitySchedule,
                                defaultAbsorptionTime: self.defaultAbsorptionTimes.medium,
                                delay: self.delay,
                                delta: self.delta
                            )
                        }

                        resultHandler(self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error)
                    }
                } else {
                    resultHandler([], .configurationError)
                }
            } else {
                resultHandler(self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], nil)
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
    public func getTotalRecentCarbValue(startDate: Date? = nil, endDate: Date? = nil, resultHandler: @escaping (_ value: CarbValue?, _ error: Error?) -> Void) {
        getRecentCarbSamples(startDate: startDate, endDate: endDate) { (entries, error) -> Void in
            resultHandler(CarbMath.totalCarbsForCarbEntries(entries), error)
        }
    }

    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        var report: [String] = [
            "## CarbStore",
            "",
            "* carbRatioSchedule: \(carbRatioSchedule?.debugDescription ?? "")",
            "* defaultAbsorptionTimes: \(defaultAbsorptionTimes)",
            "* insulinSensitivitySchedule: \(insulinSensitivitySchedule?.debugDescription ?? "")",
            "* delay: \(delay)",
            "* authorizationRequired: \(authorizationRequired)",
            "* isBackgroundDeliveryEnabled: \(isBackgroundDeliveryEnabled)"
        ]

        getRecentCarbEntries { (entries, error) in
            report.append("")
            report.append("### getRecentCarbEntries")

            if let error = error {
                report.append("Error: \(error)")
            } else {
                report.append("")
                for entry in entries {
                    report.append("* \(entry.startDate), \(entry.quantity), \(entry.absorptionTime ?? self.defaultAbsorptionTimes.medium), \(entry.createdByCurrentApp ? "" : "External")")
                }
            }

            completionHandler(report.joined(separator: "\n"))
        }
    }

    private func syncExternalDB() {
        getRecentCarbEntries() { (entries, error) -> Void in
            let entriesToUpload = entries.filter { (entry) in
                return !entry.isUploaded
            }
            self.syncDelegate?.carbStore(self, hasEntriesNeedingUpload: entriesToUpload, withCompletion: { (externalIds) in
                if externalIds.count != entriesToUpload.count {
                    // Upload failed
                    return
                }
                for (entry,id) in zip(entriesToUpload,externalIds) {
                    let newEntry = NewCarbEntry(quantity: entry.quantity, startDate: entry.startDate, foodType: entry.foodType, absorptionTime: entry.absorptionTime, isUploaded: true, externalId: id)
                    self.replaceCarbEntryInternal(entry, withEntry: newEntry, resultHandler: { (replaced, entry, error) in
                        if let error = error {
                            print("Unable to mark local carb entry as uploaded: \(error)")
                        }
                    })
                }
            })
        }

        dataAccessQueue.async {

            if self.modifiedCarbEntries.count > 0 {
                self.syncDelegate?.carbStore(self, hasModifiedEntries: Array<StoredCarbEntry>(self.modifiedCarbEntries), withCompletion: { (uploadedEntries) in
                    if uploadedEntries.count == self.modifiedCarbEntries.count {
                        self.modifiedCarbEntries = []
                        self.persistModifiedCarbEntries()
                    }
                })
            }

            if self.deletedCarbEntryIds.count > 0 {
                self.syncDelegate?.carbStore(self, hasDeletedEntries: Array<String>(self.deletedCarbEntryIds), withCompletion: { (ids) in
                    if ids.count == self.deletedCarbEntryIds.count {
                        self.deletedCarbEntryIds = []
                        self.persistDeletedCarbEntryIds()
                    }
                })
            }
        }
    }

}
