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

    /// The interval of glucose data to keep in cache
    public var reflectionDataInterval: TimeInterval = TimeInterval(minutes: 30)

    /// The interval of glucose data to use for momentum calculation
    public var momentumDataInterval: TimeInterval = TimeInterval(minutes: 15)

    /// Glucose sample cache, used for calculations when HKHealthStore is unavailable
    private var sampleDataCache: [HKQuantitySample] = []

    private var dataAccessQueue: DispatchQueue = DispatchQueue(label: "com.loudnate.GlucoseKit.dataAccessQueue")

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

     - Parameters:
        - values:        A an array of value tuples:
            - `quantity`:      The glucose sample quantity
            - `date`:          The date the sample was collected
            - `isDisplayOnly`: Whether the reading was shifted for visual consistency after calibration
        - device:        The description of the device the collected the sample
        - completion: A closure called once the glucose values were saved. The closure takes three arguments:
        - success: Whether the sample was successfully saved
        - samples: The saved samples
        - error:   An error object explaining why the save failed
     */
    public func addGlucoseValues(_ values: [(quantity: HKQuantity, date: Date, isDisplayOnly: Bool)], device: HKDevice?, completion: @escaping (_ success: Bool, _ samples: [GlucoseValue]?, _ error: Error?) -> Void) {
        guard values.count > 0 else {
            completion(false, [], nil)
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
                    self.unionSampleDataCache(with: glucose)
                    self.purgeOldGlucoseSamples()

                    if let latestGlucose = self.sampleDataCache.last, self.latestGlucose == nil || self.latestGlucose!.startDate < latestGlucose.startDate {
                        self.latestGlucose = latestGlucose
                    }

                    completion(completed, glucose, error)
                } else {
                    completion(completed, [], error)
                }
            }
        }) 
    }

    /**
     Cleans the in-memory and HealthKit caches.
     
     *This method should only be called from the `dataAccessQueue`*
     */
    private func purgeOldGlucoseSamples() {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        let cacheStartDate = Date(timeIntervalSinceNow: -max(momentumDataInterval, reflectionDataInterval))

        sampleDataCache = sampleDataCache.filter { $0.startDate >= cacheStartDate }

        if let managedDataInterval = managedDataInterval {
            let predicate = HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -maxPurgeInterval), end: Date(timeIntervalSinceNow: -managedDataInterval), options: [])

            healthStore.deleteObjects(of: glucoseType, predicate: predicate, withCompletion: { (success, count, error) -> Void in
                // error is expected and ignored if protected data is unavailable
                // TODO: Send this to the delegate
            })
        }
    }

    private func getCachedGlucoseSamples(start: Date, end: Date? = nil, completion: @escaping (_ samples: [HKQuantitySample]) -> Void) {
        getGlucoseSamples(start: start, end: end) { (result) in
            switch result {
            case .success(let samples):
                completion(samples)
            case .failure:
                completion(self.sampleDataCache.filterDateRange(start, end))
            }
        }
    }

    private func getGlucoseSamples(start: Date, end: Date? = nil, completion: @escaping (_ result: GlucoseStoreResult<[HKQuantitySample]>) -> Void) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(sampleType: glucoseType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { (_, samples, error) -> Void in

            self.dataAccessQueue.async {
                let samples = samples as? [HKQuantitySample] ?? []

                if let lastGlucose = samples.last, self.latestGlucose == nil || self.latestGlucose!.startDate < lastGlucose.startDate {
                    self.latestGlucose = lastGlucose
                }

                if let error = error {
                    completion(.failure(error))
                } else {
                    self.unionSampleDataCache(with: samples)
                    completion(.success(samples))
                }
            }
        }

        healthStore.execute(query)
    }

    /// Retrieves glucose values from HealthKit within the specified date range
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - result: An array of glucose values, in chronological order by startDate
    public func getGlucoseValues(start: Date, end: Date? = nil, completion: @escaping (_ result: GlucoseStoreResult<[GlucoseSampleValue]>) -> Void) {
        getGlucoseSamples(start: start, end: end) { (result) -> Void in
            switch result {
            case .success(let samples):
                completion(.success(samples))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Retrieves glucose values from either HealthKit or the in-memory cache.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - completion: A closure called once the values have been retrieved
    ///   - values: An array of glucose values, in chronological order by startDate
    public func getCachedGlucoseValues(start: Date, end: Date? = nil, completion: @escaping (_ values: [GlucoseSampleValue]) -> Void) {
        getCachedGlucoseSamples(start: start, end: end) { (samples) in
            completion(samples)
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
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        let samplesToCache = samples.filter({ !self.sampleDataCache.contains($0) })

        if samplesToCache.count > 0 {
            sampleDataCache.append(contentsOf: samplesToCache)
            purgeOldGlucoseSamples()
            sampleDataCache.sort(by: { $0.startDate < $1.startDate })
        }
    }

    /**
     Calculates the momentum effect for recent glucose values

     The duration of effect data returned is determined by the `momentumDataInterval`, and the delta between data points is 5 minutes.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - Parameters:
        - completion: A closure called once the calculation has completed. The closure takes two arguments:
        - effects: The calculated effect values, or an empty array if the glucose data isn't suitable for momentum calculation.
        - error:   Error is always nil
     */
    public func getRecentMomentumEffect(_ completion: @escaping (_ effects: [GlucoseEffect], _ error: Error?) -> Void) {
        getCachedGlucoseSamples(start: Date(timeIntervalSinceNow: -momentumDataInterval)) { (samples) in
            let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(samples,
                duration: self.momentumDataInterval,
                delta: TimeInterval(minutes: 5)
            )
            completion(effects, nil)
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
    @available(*, deprecated, message: "Use getGlucoseChange(start:end:completion:) instead")
    public func getRecentGlucoseChange(_ completionHandler: @escaping (_ values: (GlucoseValue, GlucoseValue)?, _ error: Error?) -> Void) {
        getGlucoseChange(start: Date(timeIntervalSinceNow: -reflectionDataInterval)) { (change) in
            completionHandler(change, nil)
        }
    }

    /// Calculates the a change in glucose values between the specified date interval.
    /// 
    /// Values within the date interval must not include a calibration, and the returned change 
    /// values will be from the same source.
    ///
    /// - Parameters:
    ///   - start: The earliest date to include. The earliest supported date is determined by `reflectionDataInterval`.
    ///   - end: The latest date to include
    ///   - completion: A closure called once the calculation has completed
    ///   - change: A tuple of the first and last glucose values describing the change, if computable.
    public func getGlucoseChange(start: Date, end: Date? = nil, completion: @escaping (_ change: (GlucoseValue, GlucoseValue)?) -> Void) {
        getCachedGlucoseSamples(start: start, end: end) { (samples) in
            let change: (GlucoseValue, GlucoseValue)?

            if let provenanceIdentifier = samples.last?.provenanceIdentifier {
                // Enforce a single source
                let samples = GlucoseMath.filterAfterCalibration(samples).filter { $0.provenanceIdentifier == provenanceIdentifier }

                if samples.count > 1,
                    let first = samples.first,
                    let last = samples.last,
                    first.startDate < last.startDate
                {
                    change = (first, last)
                } else {
                    change = nil
                }
            } else {
                change = nil
            }

            completion(change)
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
