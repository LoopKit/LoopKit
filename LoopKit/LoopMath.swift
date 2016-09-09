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
    public static func simulationDateRangeForSamples<T: Collection>(
        _ samples: T,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        duration: TimeInterval,
        delay: TimeInterval = 0,
        delta: TimeInterval) -> (Date, Date)? where T.Iterator.Element: TimelineValue
    {
        guard samples.count > 0 else {
            return nil
        }

        let startDate: Date
        let endDate: Date

        if let fromDate = fromDate, let toDate = toDate {
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
            endDate = toDate ?? maxDate.addingTimeInterval(duration + delay).dateCeiledToTimeInterval(delta)
        }
        
        return (startDate, endDate)
    }

    /**
     Calculates a timeline of glucose effects by applying a linear decay to a rate of change.
 
     - parameter sample:   The starting glucose value
     - parameter rate:     The glucose velocity
     - parameter duration: The duration the effect should continue before ending
     - parameter delta:    The time differential for the returned values
  
     - returns: An array of glucose effects
     */
    public static func decayEffect<T: GlucoseValue>(from sample: T, atRate rate: HKQuantity, for duration: TimeInterval, withDelta delta: TimeInterval = TimeInterval(minutes: 5)) -> [GlucoseEffect] {
        guard let (startDate, endDate) = simulationDateRangeForSamples([sample], duration: duration, delta: delta) else {
            return []
        }

        let glucoseUnit = HKUnit.milligramsPerDeciliterUnit()
        let velocityUnit = glucoseUnit.unitDivided(by: HKUnit.second())

        // The starting rate, which we will decay to 0 over the specified duration
        let intercept = rate.doubleValue(for: velocityUnit) // mg/dL/s
        let decayStartDate = startDate.addingTimeInterval(delta)
        let slope = -intercept / (duration - delta)  // mg/dL/s/s

        var values = [GlucoseEffect(startDate: startDate, quantity: sample.quantity)]
        var date = decayStartDate
        var lastValue = sample.quantity.doubleValue(for: glucoseUnit)

        repeat {
            let value = lastValue + (intercept + slope * date.timeIntervalSince(decayStartDate)) * delta
            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: glucoseUnit, doubleValue: value)))
            lastValue = value
            date = date.addingTimeInterval(delta)
        } while date < endDate

        return values
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
    public static func predictGlucose(_ startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [GlucoseEffect]...) -> [GlucoseValue] {
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
    public static func predictGlucose(_ startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [[GlucoseEffect]]) -> [GlucoseValue] {
        var effectValuesAtDate: [Date: Double] = [:]
        let unit = HKUnit.milligramsPerDeciliterUnit()

        for timeline in effects {
            var previousEffectValue: Double = timeline.first?.quantity.doubleValue(for: unit) ?? 0

            for effect in timeline {
                let value = effect.quantity.doubleValue(for: unit)
                effectValuesAtDate[effect.startDate as Date] = (effectValuesAtDate[effect.startDate as Date] ?? 0) + value - previousEffectValue
                previousEffectValue = value
            }
        }

        // Blend the momentum effect linearly into the summed effect list
        if momentum.count > 1 {
            var previousEffectValue: Double = momentum[0].quantity.doubleValue(for: unit)

            // The blend begins delta minutes after after the last glucose (1.0) and ends at the last momentum point (0.0)
            // We're assuming the first one occurs on or before the starting glucose.
            let blendCount = momentum.count - 2

            let timeDelta = momentum[1].startDate.timeIntervalSince(momentum[0].startDate as Date)

            // The difference between the first momentum value and the starting glucose value
            let momentumOffset = startingGlucose.startDate.timeIntervalSince(momentum[0].startDate as Date)

            let blendSlope = 1.0 / Double(blendCount)
            let blendOffset = momentumOffset / timeDelta * blendSlope

            for (index, effect) in momentum.enumerated() {
                let value = effect.quantity.doubleValue(for: unit)
                let effectValueChange = value - previousEffectValue

                let split = min(1.0, max(0.0, Double(momentum.count - index) / Double(blendCount) - blendSlope + blendOffset))
                let effectBlend = (1.0 - split) * (effectValuesAtDate[effect.startDate as Date] ?? 0)
                let momentumBlend = split * effectValueChange

                effectValuesAtDate[effect.startDate as Date] = effectBlend + momentumBlend

                previousEffectValue = value
            }
        }

        let prediction = effectValuesAtDate.sorted { $0.0 < $1.0 }.reduce([PredictedGlucoseValue(startDate: startingGlucose.startDate, quantity: startingGlucose.quantity)]) { (prediction, effect) -> [GlucoseValue] in
            if effect.0 > startingGlucose.startDate as Date, let lastValue = prediction.last {
                let nextValue: GlucoseValue = PredictedGlucoseValue(
                    startDate: effect.0,
                    quantity: HKQuantity(unit: unit, doubleValue: effect.1 + lastValue.quantity.doubleValue(for: unit))
                )
                return prediction + [nextValue]
            } else {
                return prediction
            }
        }

        return prediction
    }
}
