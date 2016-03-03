//
//  LoopMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public struct LoopMath {
    public static func simulationDateRangeForSamples<T: CollectionType where T.Generator.Element: TimelineValue>(
        samples: T,
        fromDate: NSDate? = nil,
        toDate: NSDate? = nil,
        duration: NSTimeInterval,
        delay: NSTimeInterval = 0,
        delta: NSTimeInterval) -> (NSDate, NSDate)?
    {
        guard samples.count > 0 else {
            return nil
        }

        let startDate: NSDate
        let endDate: NSDate

        if let fromDate = fromDate, toDate = toDate {
            startDate = fromDate
            endDate = toDate
        } else {
            var minDate = samples.first!.startDate
            var maxDate = minDate

            for sample in samples {
                if sample.startDate < minDate {
                    minDate = sample.startDate
                }

                if sample.endDate > maxDate {
                    maxDate = sample.endDate
                }
            }

            startDate = fromDate ?? minDate.dateFlooredToTimeInterval(delta)
            endDate = toDate ?? maxDate.dateByAddingTimeInterval(duration + delay).dateCeiledToTimeInterval(delta)
        }
        
        return (startDate, endDate)
    }

    /**
     Calculates a timeline of predicted glucose values from a variety of effects timelines.

     Glucose effect timelines are applied with equal weight.
     Each overlapping effect timeline should have matching deltas to ensure a smooth result.

     - parameter startingGlucose: The starting glucose value
     - parameter momentum:        The momentum effect determined from prior glucose values
     - parameter effects:         The glucose effect timelines to apply to the prediction.

     - returns: A timeline of glucose values
     */
    public static func predictGlucose(startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [GlucoseEffect]...) -> [GlucoseValue] {

        return []
    }
}
