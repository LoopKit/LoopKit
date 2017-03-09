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


public enum GlucoseStoreResult<T> {
    case success(T)
    case failure(Error)
}


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
 0    [managedDataInterval?]
 |––––––––––––|
```
 * HealthKit data, managed by the manufacturer's application
```
      [managedDataInterval?]           [maxPurgeInterval]
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

    /// The interval before which glucose values should be purged from HealthKit. If nil, glucose values are not purged.
    public var managedDataInterval: TimeInterval? = TimeInterval(hours: 3)

    /// The interval of glucose data to use for reflection adjustments
    public var reflectionDataInterval: TimeInterval = TimeInterval(minutes: 30)

    /// The interval of glucose data to use for momentum calculation
    public var momentumDataInterval: TimeInterval = TimeInterval(minutes: 15)

    /// Glucose sample cache, used for calculations when HKHealthStore is unavailable
    private var sampleDataCache: [HKQuantitySample] = []

    private var dataAccessQueue: DispatchQueue = DispatchQueue(label: "com.loudnate.GlucoseKit.dataAccessQueue", attributes: [])

    /// The most-recent glucose value. Reading this value is thread-safe as `GlucoseValue` is immutable.
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
     - parameter completionHandler: A closure called once the glucose values were saved. The closure takes three arguments:
        - success: Whether the sample was successfully saved
        - samples: The saved samples
        - error:   An error object explaining why the save failed
     */
    public func addGlucoseValues(_ values: [(quantity: HKQuantity, date: Date, isDisplayOnly: Bool)], device: HKDevice?, completionHandler: @escaping (_ success: Bool, _ samples: [GlucoseValue]?, _ error: Error?) -> Void) {
        guard values.count > 0 else {
            completionHandler(false, [], nil)
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

                    completionHandler(completed, sortedGlucose.map({ $0 as GlucoseValue }), error)
                } else {
                    completionHandler(completed, [], error)
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

    private func glucoseSamplesPredicate(start: Date, end: Date?) -> NSPredicate {
        return HKQuery.predicateForSamples(
            withStart: start,
            end: end ?? Date.distantFuture,
            options: [.strictStartDate]
        )
    }

    private func getCachedGlucoseSamples(start: Date, end: Date? = nil, completionHandler: @escaping (_ samples: [HKQuantitySample]) -> Void) {
        if UIApplication.shared.isProtectedDataAvailable {
            getGlucoseSamples(start: start, end: end) { (result) in
                switch result {
                case .success(let samples):
                    completionHandler(samples)
                case .failure:
                    completionHandler(self.sampleDataCache.filterDateRange(start, end))
                }
            }
        } else {
            dataAccessQueue.async {
                let samples = self.sampleDataCache.filterDateRange(start, end)
                completionHandler(samples)
            }
        }
    }

    private func getGlucoseSamples(start: Date, end: Date? = nil, completionHandler: @escaping (_ result: GlucoseStoreResult<[HKQuantitySample]>) -> Void) {
        let predicate = glucoseSamplesPredicate(start: start, end: end)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: Int(HKObjectQueryNoLimit), sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

            self.dataAccessQueue.async {
                if let lastGlucose = samples?.last as? HKQuantitySample, self.latestGlucose == nil || self.latestGlucose!.startDate < lastGlucose.startDate {
                    self.latestGlucose = lastGlucose
                }

                if let error = error {
                    completionHandler(.failure(error))
                } else {
                    completionHandler(.success((samples as? [HKQuantitySample]) ?? []))
                }
            }
        }

        healthStore.execute(query)
    }

    /// Retrieves glucose values from HealthKit within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, provided
    ///   - completionHandler: A closure called once the values have been retrieved
    ///   - result: An array of glucose values, in chronological order by startDate
    public func getGlucoseValues(start: Date, end: Date? = nil, completionHandler: @escaping (_ result: GlucoseStoreResult<[GlucoseValue]>) -> Void) {
        getGlucoseSamples(start: start, end: end) { (result) -> Void in
            switch result {
            case .success(let samples):
                completionHandler(.success(samples.map { $0 }))
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }

    /**
     Retrieves recent glucose values from HealthKit.
     
     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of values to retrieve.
     - parameter endDate:        The latest date of values to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the values have been retrieved. The closure takes two arguments:
        - values: The retrieved values
        - error:  An error object explaining why the retrieval failed
     */
    @available(*, deprecated, message: "Use getGlucoseValues(start:end:completionHandler:) instead")
    public func getRecentGlucoseValues(startDate: Date, endDate: Date? = nil, resultsHandler: @escaping (_ values: [GlucoseValue], _ error: Error?) -> Void) {
        getGlucoseValues(start: startDate, end: endDate) { (result) in
            switch result {
            case .success(let samples):
                resultsHandler(samples, nil)
            case .failure(let error):
                resultsHandler([], error)
            }
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

     The duration of effect data returned is determined by the `momentumDataInterval`, and the delta between data points is 5 minutes.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - Parameters:
        - completionHandler: A closure called once the calculation has completed. The closure takes two arguments:
        - effects: The calculated effect values, or an empty array if the glucose data isn't suitable for momentum calculation.
        - error:   Error is always nil
     */
    public func getRecentMomentumEffect(_ completionHandler: @escaping (_ effects: [GlucoseEffect], _ error: Error?) -> Void) {
        getCachedGlucoseSamples(start: Date(timeIntervalSinceNow: -momentumDataInterval)) { (samples) in
            self.unionSampleDataCache(with: samples)
            let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(samples,
                duration: self.momentumDataInterval,
                delta: TimeInterval(minutes: 5)
            )
            completionHandler(effects, nil)
        }
    }

    /**
     Calculates the recent change in glucose values

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - Parameters:
        - completionHandler: A closure called once the calculation has completed. The closure takes two arguments:
        - values:       The first and last glucose values in the requested period, or nil if the glucose data is missing or contains a calibration shift
        - error:        Error is always nil
     */
    public func getRecentGlucoseChange(_ completionHandler: @escaping (_ values: (GlucoseValue, GlucoseValue)?, _ error: Error?) -> Void) {
        getCachedGlucoseSamples(start: Date(timeIntervalSinceNow: -reflectionDataInterval)) { (samples) in
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

            completionHandler(change, nil)
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
            "* latestGlucoseValue: \(String(reflecting: latestGlucose))",
            "* managedDataInterval: \(managedDataInterval ?? 0)",
            "* reflectionDataInterval: \(reflectionDataInterval)",
            "* momentumDataInterval: \(momentumDataInterval)",
            "* sampleDataCache: \(sampleDataCache)",
            "* authorizationRequired: \(authorizationRequired)"
        ]

        completionHandler(report.joined(separator: "\n"))
    }
}
