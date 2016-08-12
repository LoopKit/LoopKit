//
//  GlucoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


/**
 Manages storage, retrieval, and calculation of glucose data.
 
 There are three tiers of storage:
 
 * In-memory cache, used for momentum calculation
```
 0    [momentumDataInterval]
 |––––|
```
 * HealthKit data, managed by the current application
```
 0    [managedDataInterval]
 |––––––––––––|
```
 * HealthKit data, managed by the manufacturer's application
```
      [managedDataInterval]           [maxPurgeInterval]
              |–––––––––--->
```
 */
public final class GlucoseStore: HealthKitSampleStore {

    private let glucoseType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!

    public override var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    /// The oldest interval to include when purging managed data
    private let maxPurgeInterval: NSTimeInterval = NSTimeInterval(hours: 24) * 7

    /// The interval before which glucose values should be purged from HealthKit.
    private var managedDataInterval: NSTimeInterval? = NSTimeInterval(hours: 3)

    /// The interval of glucose data to use for momentum calculation
    private var momentumDataInterval: NSTimeInterval = NSTimeInterval(minutes: 15)

    /// Glucose sample cache, used for momentum calculation
    private var momentumDataCache: Set<HKQuantitySample> = []

    private var dataAccessQueue: dispatch_queue_t = dispatch_queue_create("com.loudnate.GlucoseKit.dataAccessQueue", DISPATCH_QUEUE_SERIAL)

    public private(set) var latestGlucose: GlucoseValue?

    /**
     Add a new glucose value to HealthKit.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter quantity:      The glucose sample quantity
     - parameter date:          The date the sample was collected
     - parameter isDisplayOnly: Whether the reading was shifted for visual consistency after calibration
     - parameter device:        The description of the device the collected the sample
     - parameter resultHandler: A closure called once the glucose value was saved. The closure takes three arguments:
        - success: Whether the sample was successfully saved
        - sample:  The sample object
        - error:   An error object explaining why the save failed
     */
    public func addGlucose(quantity: HKQuantity, date: NSDate, isDisplayOnly: Bool, device: HKDevice?, resultHandler: (success: Bool, sample: GlucoseValue?, error: NSError?) -> Void) {

        addGlucoseValues([(quantity: quantity, date: date, isDisplayOnly: isDisplayOnly)], device: device) { (success, samples, error) in
            resultHandler(success: success, sample: samples?.last, error: error)
        }
    }

    /**
     Add new glucose values to HealthKit.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter values:        A an array of value tuples:
        - quantity:      The glucose sample quantity
        - date:          The date the sample was collected
        - isDisplayOnly: Whether the reading was shifted for visual consistency after calibration
     - parameter device:        The description of the device the collected the sample
     - parameter resultHandler: A closure called once the glucose values were saved. The closure takes three arguments:
        - success: Whether the sample was successfully saved
        - samples: The saved samples
        - error:   An error object explaining why the save failed
     */
    public func addGlucoseValues(values: [(quantity: HKQuantity, date: NSDate, isDisplayOnly: Bool)], device: HKDevice?, resultHandler: (success: Bool, samples: [GlucoseValue]?, error: NSError?) -> Void) {
        guard values.count > 0 else {
            resultHandler(success: false, samples: [], error: nil)
            return
        }

        let glucose = values.map {
            return HKQuantitySample(
                type: glucoseType,
                quantity: $0.quantity,
                startDate: $0.date,
                endDate: $0.date,
                device: device,
                metadata: [
                    MetadataKeyGlucoseIsDisplayOnly: $0.isDisplayOnly
                ]
            )
        }

        healthStore.saveObjects(glucose) { (completed, error) in
            dispatch_async(self.dataAccessQueue) {
                if completed {
                    self.momentumDataCache.unionInPlace(glucose)
                    self.purgeOldGlucoseSamples()

                    let sortedGlucose = glucose.sort({ $0.startDate < $1.startDate })

                    if let latestGlucose = sortedGlucose.last where self.latestGlucose == nil || self.latestGlucose!.startDate < latestGlucose.startDate {
                        self.latestGlucose = latestGlucose
                    }

                    resultHandler(success: completed, samples: sortedGlucose.map({ $0 as GlucoseValue }), error: error)
                } else {
                    resultHandler(success: completed, samples: [], error: error)
                }
            }
        }
    }

    /**
     Cleans the in-memory and HealthKit caches.
     
     *This method should only be called from the `dataAccessQueue`*
     */
    private func purgeOldGlucoseSamples() {
        let momentumStartDate = NSDate(timeIntervalSinceNow: -momentumDataInterval)

        momentumDataCache = Set(momentumDataCache.filter { $0.startDate >= momentumStartDate })

        if let managedDataInterval = managedDataInterval {
            guard UIApplication.sharedApplication().protectedDataAvailable else {
                return
            }

            let predicate = HKQuery.predicateForSamplesWithStartDate(NSDate(timeIntervalSinceNow: -maxPurgeInterval), endDate: NSDate(timeIntervalSinceNow: -managedDataInterval), options: [])

            healthStore.deleteObjectsOfType(glucoseType, predicate: predicate, withCompletion: { (success, count, error) -> Void in
                if let error = error {
                    // TODO: Send this to the delegate
                    NSLog("Error deleting objects: %@", error)
                }
            })
        }
    }

    private func recentSamplesPredicate(startDate startDate: NSDate?, endDate: NSDate?) -> NSPredicate {
        var startDate = startDate

        if startDate == nil, let managedDataInterval = managedDataInterval {
            startDate = NSDate(timeIntervalSinceNow: -managedDataInterval)
        }

        return HKQuery.predicateForSamplesWithStartDate(
            startDate,
            endDate: endDate ?? NSDate.distantFuture(),
            options: [.StrictStartDate]
        )
    }

    private func getCachedGlucoseSamples(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (samples: [HKQuantitySample], error: NSError?) -> Void) {
        dispatch_async(dataAccessQueue) {
            let samples = self.momentumDataCache.filterDateRange(startDate, endDate)
            resultsHandler(samples: samples, error: nil)
        }
    }

    private func getRecentGlucoseSamples(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (samples: [HKQuantitySample], error: NSError?) -> Void) {
        if UIApplication.sharedApplication().protectedDataAvailable {
            let predicate = recentSamplesPredicate(startDate: startDate, endDate: endDate)
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

            let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

                if let error = error where error.code == HKErrorCode.ErrorDatabaseInaccessible.rawValue {
                    self.getCachedGlucoseSamples(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
                } else {
                    if let lastGlucose = samples?.last as? HKQuantitySample where self.latestGlucose == nil || self.latestGlucose!.startDate < lastGlucose.startDate {
                        self.latestGlucose = lastGlucose
                    }

                    resultsHandler(
                        samples: (samples as? [HKQuantitySample]) ?? [],
                        error: error
                    )
                }
            }

            healthStore.executeQuery(query)
        } else {
            getCachedGlucoseSamples(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
        }
    }

    /**
     Retrieves recent glucose values from HealthKit.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of values to retrieve. Defaults to the managed data interval before the current date.
     - parameter endDate:        The latest date of values to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the values have been retrieved. The closure takes two arguments:
        - values: The retrieved values
        - error:  An error object explaining why the retrieval failed
     */
    public func getRecentGlucoseValues(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (values: [GlucoseValue], error: NSError?) -> Void) {
        getRecentGlucoseSamples(startDate: startDate, endDate: endDate) { (values, error) -> Void in
            resultsHandler(values: values.map { $0 }, error: error)
        }
    }

    // MARK: - Math

    /**
     Calculates the momentum effect for recent glucose values

     - parameter resultsHandler: A closure called once the calculation has completed. The closure takes two arguments:
        - effects: The calculated effect values
        - error:   An error explaining why the calculation failed
    */
    public func getRecentMomentumEffect(resultsHandler: (effects: [GlucoseEffect], error: NSError?) -> Void) {
        getRecentGlucoseSamples(startDate: NSDate(timeIntervalSinceNow: -momentumDataInterval), endDate: NSDate.distantFuture()) { (samples, error) -> Void in
            dispatch_async(self.dataAccessQueue) {
                self.momentumDataCache.unionInPlace(samples)
            }

            resultsHandler(effects: GlucoseMath.linearMomentumEffectForGlucoseEntries(samples), error: error)
        }
    }
}
