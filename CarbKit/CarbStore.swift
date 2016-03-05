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
    /**
     Informs the delegate that an internal error occurred

     - parameter carbStore: The carb store
     - parameter error:     The error describing the issue
     */
    func carbStore(carbStore: CarbStore, didError error: CarbStore.Error)
}


/**
 Manages storage, retrieval, and calculation of carbohydrate data.

 There are three tiers of storage:

 * In-memory cache, used for COB and glucose effect calculation
 ```
 0    [maximumAbsorptionTimeInterval]
 |––––––––––––|
 ```
 * Short-term persistant cache, stored in NSUserDefaults, used to re-populate the in-memory cache if the app is suspended and re-launched while the Health database is protected
 ```
 0    [maximumAbsorptionTimeInterval]
 |––––––––––––|
 ```
 * HealthKit data, managed by the current application and persisted indefinitely
 ```
 0
 |––––––––––––––––––--->
 ```
 */
public class CarbStore: HealthKitSampleStore {
    public typealias CarbEntryCacheRawValue = [[String: AnyObject]]

    public typealias DefaultAbsorptionTimes = (fast: NSTimeInterval, medium: NSTimeInterval, slow: NSTimeInterval)

    public static let CarbEntriesDidUpdateNotification = "com.loudnate.CarbKit.CarbEntriesDidUpdateNotification"

    public enum Error: ErrorType {
        case ConfigurationError
        case HealthStoreError(NSError)
        case UnauthorizedError(description: String, recoverySuggestion: String)
        case ArgumentError(description: String, recoverySuggestion: String)
    }

    private let carbType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCarbohydrates)!

    /// All the sample types we need permission to read.
    /// Eventually, we may want to consider fat, protein, and other factors to estimate carb absorption.
    public override var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: carbType)
    }

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: carbType)
    }

    /// The preferred unit. iOS currently only supports grams for dietary carbohydrates.
    public private(set) var preferredUnit: HKUnit = HKUnit.gramUnit()

    /// Carbohydrate-to-insulin ratio
    public var carbRatioSchedule: CarbRatioSchedule? {
        didSet {
            dispatch_async(dataAccessQueue) {
                self.clearCalculationCache()
            }
        }
    }

    /// A trio of default carbohydrate absorption times. Defaults to 2, 3, and 4 hours.
    public let defaultAbsorptionTimes: DefaultAbsorptionTimes

    /// Insulin-to-glucose sensitivity
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        didSet {
            dispatch_async(dataAccessQueue) {
                self.clearCalculationCache()
            }
        }
    }

    /// The longest expected absorption time interval for carbohydrates. Defaults to 4 hours.
    private let maximumAbsorptionTimeInterval: NSTimeInterval

    public weak var delegate: CarbStoreDelegate?

    /**
     Initializes a new instance of the store.
     
     `nil` is returned if HealthKit is not available on the current device.

     - returns: A new instance of the store
     */
    public init?(defaultAbsorptionTimes: DefaultAbsorptionTimes = (NSTimeInterval(hours: 2), NSTimeInterval(hours: 3), NSTimeInterval(hours: 4))) {
        self.defaultAbsorptionTimes = defaultAbsorptionTimes
        self.maximumAbsorptionTimeInterval = defaultAbsorptionTimes.slow
        self.carbEntryCache = Set(NSUserDefaults.standardUserDefaults().carbEntryCache ?? [])

        super.init()

        if !authorizationRequired {
            createQueries()
        }
    }

    public override func authorize(completion: (success: Bool, error: NSError?) -> Void) {
        authorize { (success: Bool, error: NSError?) -> Void in
            if success {
                self.createQueries()
            }

            completion(success: success, error: error)
        }
    }

    // MARK: - Query

    /// All active observer queries
    private var observerQueries: [HKObserverQuery] = []

    /// All active anchored object queries, by sample type
    private var anchoredObjectQueries: [HKSampleType: HKAnchoredObjectQuery] = [:]

    /// The last-retreived anchor for each anchored object query, by sample type
    private var queryAnchors: [HKSampleType: HKQueryAnchor] = [:]

    private func createQueries() {
        let predicate = recentSamplesPredicate()

        for type in readTypes {
            let observerQuery = HKObserverQuery(sampleType: type, predicate: predicate, updateHandler: { [unowned self] (query, completionHandler, error) -> Void in

                if let error = error {
                    self.delegate?.carbStore(self, didError: .HealthStoreError(error))
                } else {
                    dispatch_async(self.dataAccessQueue) {
                        if self.anchoredObjectQueries[type] == nil {
                            let anchoredObjectQuery = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: self.queryAnchors[type], limit: Int(HKObjectQueryNoLimit), resultsHandler: self.processResultsFromAnchoredQuery)
                            anchoredObjectQuery.updateHandler = self.processResultsFromAnchoredQuery

                            self.anchoredObjectQueries[type] = anchoredObjectQuery
                            self.healthStore.executeQuery(anchoredObjectQuery)
                        }
                    }
                }

                completionHandler()
            })

            healthStore.executeQuery(observerQuery)
            observerQueries.append(observerQuery)
        }
    }

    deinit {
        for query in observerQueries {
            healthStore.stopQuery(query)
        }

        for query in anchoredObjectQueries.values {
            healthStore.stopQuery(query)
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
    public func setBackgroundDeliveryEnabled(enabled: Bool, completion: (success: Bool, error: Error?) -> Void) {
        dispatch_async(self.dataAccessQueue) { () -> Void in
            let oldValue = self.isBackgroundDeliveryEnabled
            self.isBackgroundDeliveryEnabled = enabled

            switch (oldValue, enabled) {
            case (false, true):
                let group = dispatch_group_create()
                var lastError: Error?

                for type in self.readTypes {
                    dispatch_group_enter(group)
                    self.healthStore.enableBackgroundDeliveryForType(type, frequency: .Immediate, withCompletion: { [unowned self] (enabled, error) -> Void in
                        if !enabled {
                            self.isBackgroundDeliveryEnabled = oldValue

                            if let error = error {
                                lastError = .HealthStoreError(error)
                            }
                        }

                        dispatch_group_leave(group)
                    })
                }

                dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
                completion(success: enabled == self.isBackgroundDeliveryEnabled, error: lastError)
            case (true, false):
                let group = dispatch_group_create()
                var lastError: Error?

                for type in self.readTypes {
                    dispatch_group_enter(group)
                    self.healthStore.disableBackgroundDeliveryForType(type, withCompletion: { [unowned self] (disabled, error) -> Void in
                        if !disabled {
                            self.isBackgroundDeliveryEnabled = oldValue

                            if let error = error {
                                lastError = .HealthStoreError(error)
                            }
                        }

                        dispatch_group_leave(group)
                    })
                }

                dispatch_group_wait(group, DISPATCH_TIME_FOREVER)
                completion(success: enabled == self.isBackgroundDeliveryEnabled, error: lastError)
            default:
                completion(success: true, error: nil)
            }
        }
    }


    // MARK: - Data fetching

    private func processResultsFromAnchoredQuery(query: HKAnchoredObjectQuery, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, anchor: HKQueryAnchor?, error: NSError?) {

        if let error = error {
            self.delegate?.carbStore(self, didError: .HealthStoreError(error))
            return
        }

        dispatch_async(dataAccessQueue) {
            // Prune the sample data based on the startDate and deletedSamples array
            let cutoffDate = NSDate().dateByAddingTimeInterval(-self.maximumAbsorptionTimeInterval)

            self.carbEntryCache = Set(self.carbEntryCache.filter { (sample) in
                if sample.startDate < cutoffDate {
                    return false
                } else if let deletedSamples = deletedSamples where deletedSamples.contains({ $0.UUID == sample.sampleUUID }) {
                    return false
                } else {
                    return true
                }
            })

            // Append the new samples
            if let samples = newSamples as? [HKQuantitySample] {
                for sample in samples {
                    self.carbEntryCache.insert(StoredCarbEntry(sample: sample))
                }
            }

            // Update the anchor
            self.queryAnchors[query.sampleType] = anchor

            self.clearCalculationCache()
            self.persistCarbEntryCache()

            // Notify listeners
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.CarbEntriesDidUpdateNotification,
                object: self
            )
        }
    }

    private var carbEntryCache: Set<StoredCarbEntry>

    private var dataAccessQueue: dispatch_queue_t = dispatch_queue_create("com.loudnate.CarbKit.dataAccessQueue", DISPATCH_QUEUE_SERIAL)

    private var recentSamplesStartDate: NSDate {
        let calendar = NSCalendar.currentCalendar()

        return min(calendar.startOfDayForDate(NSDate()), NSDate(timeIntervalSinceNow: -maximumAbsorptionTimeInterval - NSTimeInterval(minutes: 5)))
    }

    private func recentSamplesPredicate(startDate startDate: NSDate? = nil, endDate: NSDate? = nil) -> NSPredicate {
        return HKQuery.predicateForSamplesWithStartDate(startDate ?? recentSamplesStartDate, endDate: endDate ?? NSDate.distantFuture(), options: [.StrictStartDate])
    }

    private func getRecentCarbSamples(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (entries: [StoredCarbEntry], error: Error?) -> Void) {
        if UIApplication.sharedApplication().protectedDataAvailable {
            let predicate = recentSamplesPredicate(startDate: startDate, endDate: endDate)
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

            let query = HKSampleQuery(sampleType: carbType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

                resultsHandler(
                    entries: (samples as? [HKQuantitySample])?.map {
                        StoredCarbEntry(sample: $0)
                        } ?? [],
                    error: error != nil ? .HealthStoreError(error!) : nil
                )
            }

            healthStore.executeQuery(query)
        } else {
            dispatch_async(dataAccessQueue) {
                let entries = self.carbEntryCache.filterDateRange(startDate, endDate)
                resultsHandler(entries: entries, error: nil)
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
    public func getRecentCarbEntries(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (entries: [CarbEntry], error: Error?) -> Void) {
        getRecentCarbSamples(startDate: startDate, endDate: endDate) { (entries, error) -> Void in
            resultsHandler(entries: entries.map { $0 }, error: error)
        }
    }

    public func addCarbEntry(entry: CarbEntry, resultHandler: (success: Bool, entry: CarbEntry?, error: Error?) -> Void) {
        let quantity = entry.quantity
        var metadata = [String: AnyObject]()

        if let absorptionTime = entry.absorptionTime {
            metadata[MetadataKeyAbsorptionTimeMinutes] = absorptionTime
        }

        if let foodType = entry.foodType {
            metadata[HKMetadataKeyFoodType] = foodType
        }

        let carbs = HKQuantitySample(type: carbType, quantity: quantity, startDate: entry.startDate, endDate: entry.startDate, device: nil, metadata: metadata)

        healthStore.saveObject(carbs) { (completed, error) -> Void in
            dispatch_async(self.dataAccessQueue) {
                let storedObject = StoredCarbEntry(sample: carbs, createdByCurrentApp: true)
                self.carbEntryCache.insert(storedObject)
                self.clearCalculationCache()
                self.persistCarbEntryCache()

                resultHandler(
                    success: completed,
                    entry: storedObject,
                    error: error != nil ? .HealthStoreError(error!) : nil
                )
            }
        }
    }

    public func replaceCarbEntry(oldEntry: CarbEntry, withEntry newEntry: CarbEntry, resultHandler: (success: Bool, entry: CarbEntry?, error: Error?) -> Void) {
        deleteCarbEntry(oldEntry) { (completed, error) -> Void in
            if let error = error {
                resultHandler(success: false, entry: nil, error: error)
            } else {
                self.addCarbEntry(newEntry, resultHandler: resultHandler)
            }
        }
    }

    public func deleteCarbEntry(entry: CarbEntry, resultHandler: (success: Bool, error: Error?) -> Void) {
        if let entry = entry as? StoredCarbEntry {
            if entry.createdByCurrentApp {
                let predicate = HKQuery.predicateForObjectsWithUUIDs([entry.sampleUUID])
                let query = HKSampleQuery(sampleType: carbType, predicate: predicate, limit: 1, sortDescriptors: nil, resultsHandler: { (_, objects, error) -> Void in
                    if let error = error {
                        resultHandler(success: false, error: .HealthStoreError(error))
                    } else if let objects = objects {
                        self.healthStore.deleteObjects(objects) { (success, error) in
                            resultHandler(success: success, error: error != nil ? .HealthStoreError(error!) : nil)
                        }
                    }
                })

                healthStore.executeQuery(query)
            } else {
                resultHandler(
                    success: false,
                    error: .UnauthorizedError(
                        description: NSLocalizedString("com.loudnate.CarbKit.deleteCarbEntryUnownedErrorDescription", tableName: "CarbKit", value: "Authorization Denied", comment: "The description of an error returned when attempting to delete a sample not shared by the current app"),
                        recoverySuggestion: NSLocalizedString("com.loudnate.carbKit.sharingDeniedErrorRecoverySuggestion", tableName: "CarbKit", value: "This sample can be deleted from the Health app", comment: "The error recovery suggestion when attempting to delete a sample not shared by the current app")
                    )
                )
            }
        } else {
            resultHandler(
                success: false,
                error: .ArgumentError(
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
        NSUserDefaults.standardUserDefaults().carbEntryCache = Array<StoredCarbEntry>(carbEntryCache)
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

    public func carbsOnBoardAtDate(date: NSDate, resultHandler: (value: CarbValue?, error: Error?) -> Void) {
        getCarbsOnBoardValues { (values, error) -> Void in
            resultHandler(value: values.closestToDate(date), error: error)
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
    public func getCarbsOnBoardValues(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultHandler: (values: [CarbValue], error: Error?) -> Void) {
        dispatch_async(dataAccessQueue) { [unowned self] in
            if self.carbsOnBoardCache == nil {
                self.getRecentCarbSamples { (entries, error) -> Void in
                    if error == nil {
                        self.carbsOnBoardCache = CarbMath.carbsOnBoardForCarbEntries(entries, defaultAbsorptionTime: self.defaultAbsorptionTimes.medium)
                    }

                    resultHandler(values: self.carbsOnBoardCache?.filterDateRange(startDate, endDate).map { $0 } ?? [], error: error)
                }
            } else {
                resultHandler(values: self.carbsOnBoardCache?.filterDateRange(startDate, endDate) ?? [], error: nil)
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
    public func getGlucoseEffects(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultHandler: (effects: [GlucoseEffect], error: Error?) -> Void) {
        dispatch_async(dataAccessQueue) {
            if self.glucoseEffectsCache == nil {
                if let carbRatioSchedule = self.carbRatioSchedule, insulinSensitivitySchedule = self.insulinSensitivitySchedule {
                    self.getRecentCarbSamples { (entries, error) -> Void in
                        if error == nil {
                            self.glucoseEffectsCache = CarbMath.glucoseEffectsForCarbEntries(entries,
                                carbRatios: carbRatioSchedule,
                                insulinSensitivities: insulinSensitivitySchedule,
                                defaultAbsorptionTime: self.defaultAbsorptionTimes.medium
                            )
                        }

                        resultHandler(effects: self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error: error)
                    }
                } else {
                    resultHandler(effects: [], error: .ConfigurationError)
                }
            } else {
                resultHandler(effects: self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error: nil)
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
    public func getTotalRecentCarbValue(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultHandler: (value: CarbValue?, error: Error?) -> Void) {
        getRecentCarbSamples(startDate: startDate, endDate: endDate) { (entries, error) -> Void in
            resultHandler(value: CarbMath.totalCarbsForCarbEntries(entries), error: error)
        }
    }
}
