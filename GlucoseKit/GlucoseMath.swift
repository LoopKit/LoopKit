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
private let CalculationUnit = HKUnit.milligramsPerDeciliterUnit()


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
            isContinuous(samples) && isCalibrated(samples),
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

        var date = startDate
        var values = [GlucoseEffect]()

        repeat {
            let value = max(0, date.timeIntervalSince(lastSample.startDate)) * slope

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: CalculationUnit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }
}
