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


public class GlucoseStore: HealthKitSampleStore {

    private let glucoseType = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!

    public override var readTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    public override var shareTypes: Set<HKSampleType> {
        return Set(arrayLiteral: glucoseType)
    }

    /// The maximum interval to purge automatically
    private var purgeBeforeInterval: NSTimeInterval = NSTimeInterval(hours: 24) * 7

    /// The interval before which glucose values should be purged from HealthKit.
    private var purgeAfterInterval: NSTimeInterval? = NSTimeInterval(hours: 3)

    /**
     Add a new glucose value to HealthKit

     - parameter quantity:      The glucose sample quantity
     - parameter date:          The date the sample was collected
     - parameter device:        The description of the device the collected the sample
     - parameter resultHandler: A closure called once the glucose value was saved. The closure takes three arguments:
        - success: Whether the sample was successfully saved
        - sample:  The sample object
        - error:   An error object explaining why the save failed
     */
    public func addGlucose(quantity: HKQuantity, date: NSDate, device: HKDevice?, resultHandler: (success: Bool, sample: HKQuantitySample?, error: NSError?) -> Void) {

        let glucose = HKQuantitySample(type: glucoseType, quantity: quantity, startDate: date, endDate: date, device: device, metadata: nil)

        healthStore.saveObject(glucose) { (completed, error) -> Void in
            resultHandler(success: completed, sample: glucose, error: error)
        }

        purgeOldGlucoseSamples()
    }

    private func purgeOldGlucoseSamples() {
        if let purgeAfterInterval = purgeAfterInterval {
            guard UIApplication.sharedApplication().protectedDataAvailable else {
                return
            }

            let predicate = HKQuery.predicateForSamplesWithStartDate(NSDate(timeIntervalSinceNow: -purgeBeforeInterval), endDate: NSDate(timeIntervalSinceNow: -purgeAfterInterval), options: [])

            healthStore.deleteObjectsOfType(glucoseType, predicate: predicate, withCompletion: { (success, count, error) -> Void in
                if let error = error {
                    // TODO: Remote error handling
                    NSLog("Error deleting objects: %@", error)
                }
            })
        }
    }

    private func recentSamplesPredicate(interval: NSTimeInterval) -> NSPredicate {
        return HKQuery.predicateForSamplesWithStartDate(NSDate(timeIntervalSinceNow: -interval), endDate: NSDate.distantFuture(), options: [.StrictStartDate])
    }

    private func recentSamplesSortDescriptors() -> [NSSortDescriptor] {
        return [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
    }

    public func getRecentGlucoseValues(forTimeInterval interval: NSTimeInterval = NSTimeInterval(hours: 6), resultsHandler: (values: [GlucoseValue], error: NSError?) -> Void) {
        let query = HKSampleQuery(sampleType: glucoseType, predicate: recentSamplesPredicate(interval), limit: Int(HKObjectQueryNoLimit), sortDescriptors: recentSamplesSortDescriptors()) { (_, samples, error) -> Void in

            resultsHandler(
                values: (samples as? [HKQuantitySample])?.map { GlucoseValue(startDate: $0.startDate, quantity: $0.quantity) } ?? [],
                error: error
            )
        }

        healthStore.executeQuery(query)
    }
}
