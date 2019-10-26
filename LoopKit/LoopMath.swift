//
//  LoopMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public enum LoopMath {
    static func simulationDateRangeForSamples<T: Collection>(
        _ samples: T,
        from start: Date? = nil,
        to end: Date? = nil,
        duration: TimeInterval,
        delay: TimeInterval = 0,
        delta: TimeInterval
    ) -> (start: Date, end: Date)? where T.Element: TimelineValue {
        guard samples.count > 0 else {
            return nil
        }

        if let start = start, let end = end {
            return (start: start.dateFlooredToTimeInterval(delta), end: end.dateCeiledToTimeInterval(delta))
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

            return (
                start: (start ?? minDate).dateFlooredToTimeInterval(delta),
                end: (end ?? maxDate.addingTimeInterval(duration + delay)).dateCeiledToTimeInterval(delta)
            )
        }
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
    public static func predictGlucose(startingAt startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [GlucoseEffect]...) -> [PredictedGlucoseValue] {
        return predictGlucose(startingAt: startingGlucose, momentum: momentum, effects: effects)
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
    public static func predictGlucose(startingAt startingGlucose: GlucoseValue, momentum: [GlucoseEffect] = [], effects: [[GlucoseEffect]]) -> [PredictedGlucoseValue] {
        var effectValuesAtDate: [Date: Double] = [:]
        let unit = HKUnit.milligramsPerDeciliter

        for timeline in effects {
            var previousEffectValue: Double = timeline.first?.quantity.doubleValue(for: unit) ?? 0

            for effect in timeline {
                let value = effect.quantity.doubleValue(for: unit)
                effectValuesAtDate[effect.startDate] = (effectValuesAtDate[effect.startDate] ?? 0) + value - previousEffectValue
                previousEffectValue = value
            }
        }

        // Blend the momentum effect linearly into the summed effect list
        if momentum.count > 1 {
            var previousEffectValue: Double = momentum[0].quantity.doubleValue(for: unit)

            // The blend begins delta minutes after after the last glucose (1.0) and ends at the last momentum point (0.0)
            // We're assuming the first one occurs on or before the starting glucose.
            let blendCount = momentum.count - 2

            let timeDelta = momentum[1].startDate.timeIntervalSince(momentum[0].startDate)

            // The difference between the first momentum value and the starting glucose value
            let momentumOffset = startingGlucose.startDate.timeIntervalSince(momentum[0].startDate)

            let blendSlope = 1.0 / Double(blendCount)
            let blendOffset = momentumOffset / timeDelta * blendSlope

            for (index, effect) in momentum.enumerated() {
                let value = effect.quantity.doubleValue(for: unit)
                let effectValueChange = value - previousEffectValue

                let split = min(1.0, max(0.0, Double(momentum.count - index) / Double(blendCount) - blendSlope + blendOffset))
                let effectBlend = (1.0 - split) * (effectValuesAtDate[effect.startDate] ?? 0)
                let momentumBlend = split * effectValueChange

                effectValuesAtDate[effect.startDate] = effectBlend + momentumBlend

                previousEffectValue = value
            }
        }

        let prediction = effectValuesAtDate.sorted { $0.0 < $1.0 }.reduce([PredictedGlucoseValue(startDate: startingGlucose.startDate, quantity: startingGlucose.quantity)]) { (prediction, effect) -> [PredictedGlucoseValue] in
            if effect.0 > startingGlucose.startDate, let lastValue = prediction.last {
                let nextValue = PredictedGlucoseValue(
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


extension GlucoseValue {
    /**
     Calculates a timeline of glucose effects by applying a linear decay to a rate of change.

     - parameter rate:     The glucose velocity
     - parameter duration: The duration the effect should continue before ending
     - parameter delta:    The time differential for the returned values

     - returns: An array of glucose effects
     */
    public func decayEffect(atRate rate: HKQuantity, for duration: TimeInterval, withDelta delta: TimeInterval = 5 * 60) -> [GlucoseEffect] {
        guard let (startDate, endDate) = LoopMath.simulationDateRangeForSamples([self], duration: duration, delta: delta) else {
            return []
        }

        let glucoseUnit = HKUnit.milligramsPerDeciliter
        let velocityUnit = GlucoseEffectVelocity.perSecondUnit

        // The starting rate, which we will decay to 0 over the specified duration
        let intercept = rate.doubleValue(for: velocityUnit) // mg/dL/s
        let decayStartDate = startDate.addingTimeInterval(delta)
        let slope = -intercept / (duration - delta)  // mg/dL/s/s

        var values = [GlucoseEffect(startDate: startDate, quantity: quantity)]
        var date = decayStartDate
        var lastValue = quantity.doubleValue(for: glucoseUnit)

        repeat {
            let value = lastValue + (intercept + slope * date.timeIntervalSince(decayStartDate)) * delta
            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: glucoseUnit, doubleValue: value)))
            lastValue = value
            date = date.addingTimeInterval(delta)
        } while date < endDate

        return values
    }
}


extension BidirectionalCollection where Element == GlucoseEffect {

    /// Sums adjacent glucose effects into buckets of the specified duration.
    ///
    /// Requires the receiver to be sorted chronologically by endDate
    ///
    /// - Parameter duration: The duration of each resulting summed element
    /// - Returns: An array of summed effects
    public func combinedSums(of duration: TimeInterval) -> [GlucoseChange] {
        var sums = [GlucoseChange]()
        sums.reserveCapacity(self.count)
        var lastValidIndex = sums.startIndex

        for effect in reversed() {
            sums.append(GlucoseChange(startDate: effect.startDate, endDate: effect.endDate, quantity: effect.quantity))

            for sumsIndex in lastValidIndex..<(sums.endIndex - 1) {
                guard sums[sumsIndex].endDate <= effect.endDate.addingTimeInterval(duration) else {
                    lastValidIndex += 1
                    continue
                }

                sums[sumsIndex].append(effect)
            }
        }

        return sums.reversed()
    }
}


extension BidirectionalCollection where Element == GlucoseEffectVelocity {

    /// Subtracts an array of glucose effects with uniform intervals and no gaps from the collection of effect changes, which may not have uniform intervals.
    ///
    /// - Parameters:
    ///   - otherEffects: The array of glucose effects to subtract
    ///   - effectInterval: The time interval between elements in the otherEffects array
    /// - Returns: A resulting array of glucose effects
    public func subtracting(_ otherEffects: [GlucoseEffect], withUniformInterval effectInterval: TimeInterval) -> [GlucoseEffect] {
        // Trim both collections to match
        let otherEffects = otherEffects.filterDateRange(self.first?.endDate, nil)
        let effects = self.filterDateRange(otherEffects.first?.startDate, nil)

        var subtracted: [GlucoseEffect] = []

        var previousOtherEffectValue = otherEffects.first?.quantity.doubleValue(for: .milligramsPerDeciliter) ?? 0 // mg/dL
        var effectIndex = effects.startIndex

        for otherEffect in otherEffects.dropFirst() {
            guard effectIndex < effects.endIndex else {
                break
            }

            let otherEffectValue = otherEffect.quantity.doubleValue(for: .milligramsPerDeciliter)
            let otherEffectChange = otherEffectValue - previousOtherEffectValue
            previousOtherEffectValue = otherEffectValue

            let effect = effects[effectIndex]

            // Our effect array may have gaps, or have longer segments than 5 minutes.
            guard effect.endDate <= otherEffect.endDate else {
                continue  // Move on to the next other effect
            }

            effectIndex += 1

            let effectValue = effect.quantity.doubleValue(for: GlucoseEffectVelocity.perSecondUnit) // mg/dL/s
            let effectValueMatchingOtherEffectInterval = effectValue * effectInterval // mg/dL

            subtracted.append(GlucoseEffect(
                startDate: effect.endDate,
                quantity: HKQuantity(
                    unit: .milligramsPerDeciliter,
                    doubleValue: effectValueMatchingOtherEffectInterval - otherEffectChange
                )
            ))
        }

        // If we have run out of otherEffect items, we assume the otherEffectChange remains zero
        for effect in effects[effectIndex..<effects.endIndex] {
            let effectValue = effect.quantity.doubleValue(for: GlucoseEffectVelocity.perSecondUnit) // mg/dL/s
            let effectValueMatchingOtherEffectInterval = effectValue * effectInterval // mg/dL

            subtracted.append(GlucoseEffect(
                startDate: effect.endDate,
                quantity: HKQuantity(
                    unit: .milligramsPerDeciliter,
                    doubleValue: effectValueMatchingOtherEffectInterval
                )
            ))
        }

        return subtracted
    }
}
