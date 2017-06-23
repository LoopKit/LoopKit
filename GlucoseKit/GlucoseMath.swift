//
//  GlucoseMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


/// To determine if we have a contiguous set of values, we require readings to be an average of 5 minutes apart
private let ContinuousGlucoseInterval = TimeInterval(minutes: 5)

/// The unit to use during calculation
private let CalculationUnit = HKUnit.milligramsPerDeciliter()


struct GlucoseMath {
    /**
     Calculates slope and intercept using linear regression
     
     This implementation is not suited for large datasets.

     - parameter points: An array of tuples containing x and y values

     - returns: A tuple of slope and intercept values
     */
    private static func linearRegression(_ points: [(x: Double, y: Double)]) -> (slope: Double, intercept: Double) {
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX² = 0.0
        var sumY² = 0.0
        let count = Double(points.count)

        for point in points  {
            sumX += point.x
            sumY += point.y
            sumXY += (point.x * point.y)
            sumX² += (point.x * point.x)
            sumY² += (point.y * point.y)
        }

        let slope = ((count * sumXY) - (sumX * sumY)) / ((count * sumX²) - (sumX * sumX))
        let intercept = (sumY * sumX² - (sumX * sumXY)) / (count * sumX² - (sumX * sumX))

        return (slope: slope, intercept: intercept)
    }

    /**
     Determines whether a collection of glucose samples contain no calibration entries.
     
     - parameter samples: The sequence of glucose
     
     - returns: True if the samples do not contain calibration entries
     */
    static func isCalibrated<T: BidirectionalCollection>(_ samples: T) -> Bool where T.Iterator.Element: GlucoseSampleValue, T.Index == Int {
        return samples.filter({ $0.isDisplayOnly }).count == 0
    }

    /// Filters a timeline of glucose samples to only include those after the last calibration.
    ///
    /// - Parameter samples: The timeline of glucose samples, in chronological order
    /// - Returns: A filtered timeline
    static func filterAfterCalibration<T: BidirectionalCollection>(_ samples: T) -> [T.Iterator.Element] where T.Iterator.Element: GlucoseSampleValue, T.Index == Int {
        var postCalibration = true

        return samples.reversed().filter({ (sample) in
            if sample.isDisplayOnly {
                postCalibration = false
            }

            return postCalibration
        }).reversed()
    }

    /**
     Determines whether a collection of glucose samples can be considered continuous.
     
     - parameter samples: The sequence of glucose, in chronological order
     
     - returns: True if the samples are continuous
     */
    static func isContinuous<T: BidirectionalCollection>(_ samples: T) -> Bool where T.Iterator.Element: GlucoseSampleValue, T.IndexDistance == Int {
        if  let first = samples.first,
            let last = samples.last,
            // Ensure that the entries are contiguous
            abs(first.startDate.timeIntervalSince(last.startDate)) < ContinuousGlucoseInterval * TimeInterval(samples.count)
        {
            return true
        }

        return false
    }

    /// Determines whether a collection of glucose samples is all from the same source.
    ///
    /// - Parameter samples: The sequence of glucose
    /// - Returns: True if the samples all have the same source
    static func hasSingleProvenance<T: Collection>(_ samples: T) -> Bool where T.Iterator.Element: GlucoseSampleValue {
        let firstProvenance = samples.first?.provenanceIdentifier

        for sample in samples {
            if sample.provenanceIdentifier != firstProvenance {
                return false
            }
        }

        return true
    }

    /**
     Calculates the short-term predicted trend of a sequence of glucose values using linear regression

     - parameter samples:  The sequence of glucose, in chronological order
     - parameter duration: The trend duration to return
     - parameter delta:    The time differential for the returned values

     - returns: An array of glucose effects
     */
    static func linearMomentumEffectForGlucoseEntries<T: BidirectionalCollection>(
        _ samples: T,
        duration: TimeInterval = TimeInterval(minutes: 30),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] where T.Iterator.Element: GlucoseSampleValue, T.Index == Int, T.IndexDistance == Int {
        guard
            samples.count > 2,  // Linear regression isn't much use without 3 or more entries.
            isContinuous(samples) && isCalibrated(samples) && hasSingleProvenance(samples),
            let firstSample = samples.first,
            let lastSample = samples.last,
            let (startDate, endDate) = LoopMath.simulationDateRangeForSamples([lastSample], duration: duration, delta: delta)
        else {
            return []
        }

        let xy = samples.map { (
            x: $0.startDate.timeIntervalSince(firstSample.startDate),
            y: $0.quantity.doubleValue(for: CalculationUnit)
        ) }

        let (slope: slope, intercept: _) = linearRegression(xy)

        guard slope.isFinite else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()

        repeat {
            let value = max(0, date.timeIntervalSince(lastSample.startDate)) * slope

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: CalculationUnit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    /// Calculates a timeline of effect velocity (glucose/time) observed in glucose readings that counteract the specified effects.
    ///
    /// - Parameters:
    ///   - glucoseSamples: Glucose samples in chronological order
    ///   - effects: Glucose effects to be countered, in chronological order
    /// - Returns: An array of velocities describing the change in glucose samples compared to the specified effects
    public static func counteractionEffects(of glucoseSamples: [GlucoseSampleValue], to effects: [GlucoseEffect]) -> [GlucoseEffectVelocity] {
        let mgdL = HKUnit.milligramsPerDeciliter()
        let velocityUnit = mgdL.unitDivided(by: .second())
        var velocities = [GlucoseEffectVelocity]()
        var effectIndex = 0

        for (index, endGlucose) in glucoseSamples.dropFirst().enumerated() {
            // Find a valid change in glucose, requiring identical provenance and no calibration
            let startGlucose = glucoseSamples[index]

            guard startGlucose.provenanceIdentifier == endGlucose.provenanceIdentifier,
                !startGlucose.isDisplayOnly, !endGlucose.isDisplayOnly
            else {
                continue
            }

            let glucoseChange = endGlucose.quantity.doubleValue(for: mgdL) - startGlucose.quantity.doubleValue(for: mgdL)

            // Compare that to a change in insulin effects
            guard effects.count > effectIndex else {
                break
            }

            var startEffect: GlucoseEffect?
            var endEffect: GlucoseEffect?

            for effect in effects[effectIndex..<effects.count] {
                if startEffect == nil && effect.startDate >= startGlucose.startDate {
                    startEffect = effect
                } else if endEffect == nil && effect.startDate >= endGlucose.startDate {
                    endEffect = effect
                    break
                }

                effectIndex += 1
            }

            guard let startEffectValue = startEffect?.quantity.doubleValue(for: mgdL),
                let endEffectValue = endEffect?.quantity.doubleValue(for: mgdL)
            else {
                break
            }

            let effectChange = endEffectValue - startEffectValue
            let discrepancy = glucoseChange - effectChange
            let averageVelocity = HKQuantity(unit: velocityUnit, doubleValue: discrepancy / endGlucose.startDate.timeIntervalSince(startGlucose.startDate))
            let effect = GlucoseEffectVelocity(startDate: startGlucose.startDate, endDate: endGlucose.startDate, quantity: averageVelocity)
            
            velocities.append(effect)
        }
        
        return velocities
    }
}
