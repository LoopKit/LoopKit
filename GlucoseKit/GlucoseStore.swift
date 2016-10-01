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
 0    [max(momentumDataInterval, reflectionDataInterval)]
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

    private let glucoseType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!

    public override var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    /// The oldest interval to include when purging managed data
    private let maxPurgeInterval: TimeInterval = TimeInterval(hours: 24) * 7

    /// The interval before which glucose values should be purged from HealthKit.
    public var managedDataInterval: TimeInterval? = TimeInterval(hours: 3)

    /// The interval of glucose data to use for reflection adjustments
    public var reflectionDataInterval: TimeInterval = TimeInterval(minutes: 30)

    /// The interval of glucose data to use for momentum calculation
    public var momentumDataInterval: TimeInterval = TimeInterval(minutes: 15)

    /// Glucose sample cache, used for calculations when HKHealthStore is unavailable
    private var sampleDataCache: [HKQuantitySample] = []

    private var dataAccessQueue: DispatchQueue = DispatchQueue(label: "com.loudnate.GlucoseKit.dataAccessQueue", attributes: [])

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
    public func addGlucose(_ quantity: HKQuantity, date: Date, isDisplayOnly: Bool, device: HKDevice?, resultHandler: @escaping (_ success: Bool, _ sample: GlucoseValue?, _ error: Error?) -> Void) {

        addGlucoseValues([(quantity: quantity, date: date, isDisplayOnly: isDisplayOnly)], device: device) { (success, samples, error) in
            resultHandler(success, samples?.last, error)
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
    public func addGlucoseValues(_ values: [(quantity: HKQuantity, date: Date, isDisplayOnly: Bool)], device: HKDevice?, resultHandler: @escaping (_ success: Bool, _ samples: [GlucoseValue]?, _ error: Error?) -> Void) {
        guard values.count > 0 else {
            resultHandler(false, [], nil)
            return
        }

        let glucose = values.map {
            return HKQuantitySample(
                type: glucoseType,
                quantity: $0.quantity,
                start: $0.date,
                end: $0.date,
                device: device,
                metadata: [
                    MetadataKeyGlucoseIsDisplayOnly: $0.isDisplayOnly
                ]
            )
        }

        healthStore.save(glucose, withCompletion: { (completed, error) in
            self.dataAccessQueue.async {
                if completed {
                    let sortedGlucose = glucose.sorted { $0.startDate < $1.startDate }

                    self.sampleDataCache.append(contentsOf: sortedGlucose)
                    self.purgeOldGlucoseSamples()

                    if let latestGlucose = sortedGlucose.last, self.latestGlucose == nil || self.latestGlucose!.startDate < latestGlucose.startDate {
                        self.latestGlucose = latestGlucose
                    }

                    resultHandler(completed, sortedGlucose.map({ $0 as GlucoseValue }), error)
                } else {
                    resultHandler(completed, [], error)
                }
            }
        }) 
    }

    /**
     Cleans the in-memory and HealthKit caches.
     
     *This method should only be called from the `dataAccessQueue`*
     */
    private func purgeOldGlucoseSamples() {
        let cacheStartDate = Date(timeIntervalSinceNow: -max(momentumDataInterval, reflectionDataInterval))

        sampleDataCache = sampleDataCache.filter { $0.startDate >= cacheStartDate }

        if let managedDataInterval = managedDataInterval {
            guard UIApplication.shared.isProtectedDataAvailable else {
                return
            }

            let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maxPurgeInterval), end: Date(timeIntervalSinceNow: -managedDataInterval), options: [])

            healthStore.deleteObjects(of: glucoseType, predicate: predicate, withCompletion: { (success, count, error) -> Void in
                // TODO: Send this to the delegate
            })
        }
    }

    private func recentSamplesPredicate(startDate: Date?, endDate: Date?) -> NSPredicate {
        var startDate = startDate

        if startDate == nil, let managedDataInterval = managedDataInterval {
            startDate = Date(timeIntervalSinceNow: -managedDataInterval)
        }

        return HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate ?? Date.distantFuture,
            options: [.strictStartDate]
        )
    }

    private func getCachedGlucoseSamples(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ samples: [HKQuantitySample], _ error: Error?) -> Void) {
        dataAccessQueue.async {
            let samples = self.sampleDataCache.filterDateRange(startDate, endDate)
            resultsHandler(samples, nil)
        }
    }

    private func getRecentGlucoseSamples(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ samples: [HKQuantitySample], _ error: Error?) -> Void) {
        if UIApplication.shared.isProtectedDataAvailable {
            let predicate = recentSamplesPredicate(startDate: startDate, endDate: endDate)
            let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

            let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

                if let error = error as? NSError, error.code == HKError.errorDatabaseInaccessible.rawValue {
                    self.getCachedGlucoseSamples(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
                } else {
                    if let lastGlucose = samples?.last as? HKQuantitySample, self.latestGlucose == nil || self.latestGlucose!.startDate < lastGlucose.startDate {
                        self.latestGlucose = lastGlucose
                    }

                    resultsHandler(
                        (samples as? [HKQuantitySample]) ?? [],
                        error
                    )
                }
            }

            healthStore.execute(query)
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
    public func getRecentGlucoseValues(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ values: [GlucoseValue], _ error: Error?) -> Void) {
        getRecentGlucoseSamples(startDate: startDate, endDate: endDate) { (values, error) -> Void in
            resultsHandler(values.map { $0 }, error)
        }
    }

    // MARK: - Math

    private func unionSampleDataCache(with samples: [HKQuantitySample]) {
        self.dataAccessQueue.async {
            let samplesToCache = samples.filter({ !self.sampleDataCache.contains($0) })

            if samplesToCache.count > 0 {
                self.sampleDataCache.append(contentsOf: samplesToCache)
                self.sampleDataCache.sort(by: { $0.startDate < $1.startDate })
            }
        }
    }

    /**
     Calculates the momentum effect for recent glucose values
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter resultsHandler: A closure called once the calculation has completed. The closure takes two arguments:
        - effects: The calculated effect values
        - error:   An error explaining why the calculation failed
     */
    public func getRecentMomentumEffect(_ resultsHandler: @escaping (_ effects: [GlucoseEffect], _ error: Error?) -> Void) {
        getRecentGlucoseSamples(startDate: Date(timeIntervalSinceNow: -momentumDataInterval), endDate: Date.distantFuture) { (samples, error) -> Void in
            self.unionSampleDataCache(with: samples)
            resultsHandler(GlucoseMath.linearMomentumEffectForGlucoseEntries(samples), error)
        }
    }

    /**
     Calculates the recent change in glucose values
 
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
 
     - parameter resultsHandler: A closure called once the calculation has completed. The closure takes two arguments:
        - values:       The first and last glucose values in the requested period
        - error:        An error explaining why the calculation failed
     */
    public func getRecentGlucoseChange(_ resultsHandler: @escaping (_ values: (GlucoseValue, GlucoseValue)?, _ error: Error?) -> Void) {
        getRecentGlucoseSamples(startDate: Date(timeIntervalSinceNow: -reflectionDataInterval), endDate: Date.distantFuture) { (samples, error) in
            self.unionSampleDataCache(with: samples)

            let change: (GlucoseValue, GlucoseValue)?

            if  GlucoseMath.isCalibrated(samples) && samples.count > 2,
                let first = samples.first,
                let last = samples.last,
                first.startDate < last.startDate
            {
                change = (first, last)
            } else {
                change = nil
            }

            resultsHandler(change, error)
        }
    }

    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: A closure called once the report has been generated. The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        let report: [String] = [
            "## GlucoseStore",
            "",
            "* managedDataInterval: \(managedDataInterval ?? 0)",
            "* reflectionDataInterval: \(reflectionDataInterval)",
            "* momentumDataInterval: \(momentumDataInterval)",
            "* sampleDataCache: \(sampleDataCache)",
            "* authorizationRequired: \(authorizationRequired)"
        ]

        completionHandler(report.joined(separator: "\n"))
    }
}
