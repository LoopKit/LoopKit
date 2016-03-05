//
//  LoopMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


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

     Each effect timeline:
     - Is given equal weight, with the exception of the momentum effect timeline
     - Can be of arbitrary size and start date
     - Should be in ascending order
     - Should have aligning dates with any overlapping timelines to ensure a smooth result

     - parameter startingGlucose: The starting glucose value
     - parameter momentum:        The momentum effect timeline determined from prior glucose values
     - parameter effects:         The glucose effect timelines to apply to the prediction.

     - returns: A timeline of glucose values
     */
    public static func predictGlucose(startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [GlucoseEffect]...) -> [GlucoseValue] {
        return predictGlucose(startingGlucose, momentum: momentum, effects: effects)
    }

    /**
     Calculates a timeline of predicted glucose values from a variety of effects timelines.

     Each effect timeline:
     - Is given equal weight, with the exception of the momentum effect timeline
     - Can be of arbitrary size and start date
     - Should be in ascending order
     - Should have aligning dates with any overlapping timelines to ensure a smooth result

     - parameter startingGlucose: The starting glucose value
     - parameter momentum:        The momentum effect timeline determined from prior glucose values
     - parameter effects:         The glucose effect timelines to apply to the prediction.

     - returns: A timeline of glucose values
     */
    public static func predictGlucose(startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [[GlucoseEffect]]) -> [GlucoseValue] {
        var effectValuesAtDate: [NSDate: Double] = [:]
        let unit = HKUnit.milligramsPerDeciliterUnit()

        for timeline in effects {
            var previousEffectValue: Double = timeline.first?.quantity.doubleValueForUnit(unit) ?? 0

            for effect in timeline {
                let value = effect.quantity.doubleValueForUnit(unit)
                effectValuesAtDate[effect.startDate] = (effectValuesAtDate[effect.startDate] ?? 0) + value - previousEffectValue
                previousEffectValue = value
            }
        }

        // Blend the momentum effect linearly into the summed effect list
        if momentum.count > 1 {
            var previousEffectValue: Double = momentum[0].quantity.doubleValueForUnit(unit)

            // The blend begins delta minutes after after the last glucose (1.0) and ends at the last momentum point (0.0)
            // We're assuming the first one occurs on or before the starting glucose.
            let blendCount = momentum.count - 2

            let timeDelta = momentum[1].startDate.timeIntervalSinceDate(momentum[0].startDate)

            // The difference between the first momentum value and the starting glucose value
            let momentumOffset = startingGlucose.startDate.timeIntervalSinceDate(momentum[0].startDate)

            let blendSlope = 1.0 / Double(blendCount)
            let blendOffset = momentumOffset / timeDelta * blendSlope

            for (index, effect) in momentum.enumerate() {
                let value = effect.quantity.doubleValueForUnit(unit)
                let effectValueChange = value - previousEffectValue

                let split = min(1.0, max(0.0, Double(momentum.count - index) / Double(blendCount) - blendSlope + blendOffset))
                let effectBlend = (1.0 - split) * (effectValuesAtDate[effect.startDate] ?? 0)
                let momentumBlend = split * effectValueChange

                effectValuesAtDate[effect.startDate] = effectBlend + momentumBlend

                previousEffectValue = value
            }
        }

        let prediction = effectValuesAtDate.sort { $0.0 < $1.0 }.reduce([PredictedGlucoseValue(startDate: startingGlucose.startDate, quantity: startingGlucose.quantity)]) { (prediction, effect) -> [GlucoseValue] in
            if effect.0 > startingGlucose.startDate, let lastValue = prediction.last {
                let nextValue: GlucoseValue = PredictedGlucoseValue(
                    startDate: effect.0,
                    quantity: HKQuantity(unit: unit, doubleValue: effect.1 + lastValue.quantity.doubleValueForUnit(unit))
                )
                return prediction + [nextValue]
            } else {
                return prediction
            }
        }

        return prediction
    }
}
