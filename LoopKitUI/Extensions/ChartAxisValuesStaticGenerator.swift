//
//  ChartAxisValuesStaticGenerator.swift
//  LoopUI
//
//  Created by Nathaniel Hamming on 2020-09-08.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation


/// Generates evenly-stepped Y-axis values spanning a set of charted values.
///
/// Ported from the third-party SwiftCharts axis generators so the Apple Swift Charts
/// migration keeps the same axis segmentation behavior.
public enum ChartAxisValuesStaticGenerator {

    /// How the candidate segment step grows while searching for a step size that yields
    /// no more than `maxSegmentCount` segments.
    public enum SegmentStepGrowth {
        /// Steps grow by adding `multiple` each iteration (Loop's glucose-chart behavior)
        case linear
        /// Steps double each iteration (the original SwiftCharts behavior)
        case doubling
    }

    public static func generateYAxisValuesUsingLinearSegmentStep(chartValues: [Double],
                                                                 minSegmentCount: Double,
                                                                 maxSegmentCount: Double,
                                                                 multiple: Double,
                                                                 addPaddingSegmentIfEdge: Bool) -> [Double]
    {
        return generateYAxisValues(chartValues: chartValues,
                                   minSegmentCount: minSegmentCount,
                                   maxSegmentCount: maxSegmentCount,
                                   multiple: multiple,
                                   addPaddingSegmentIfEdge: addPaddingSegmentIfEdge,
                                   growth: .linear)
    }

    public static func generateYAxisValuesWithChartPoints(chartValues: [Double],
                                                          minSegmentCount: Double,
                                                          maxSegmentCount: Double,
                                                          multiple: Double,
                                                          addPaddingSegmentIfEdge: Bool) -> [Double]
    {
        return generateYAxisValues(chartValues: chartValues,
                                   minSegmentCount: minSegmentCount,
                                   maxSegmentCount: maxSegmentCount,
                                   multiple: multiple,
                                   addPaddingSegmentIfEdge: addPaddingSegmentIfEdge,
                                   growth: .doubling)
    }

    public static func generateYAxisValues(chartValues: [Double],
                                           minSegmentCount: Double,
                                           maxSegmentCount: Double,
                                           multiple: Double,
                                           addPaddingSegmentIfEdge: Bool,
                                           growth: SegmentStepGrowth) -> [Double]
    {
        precondition(multiple > 0, "Invalid multiple: \(multiple)")

        let sortedValues = chartValues.sorted()

        guard let first = sortedValues.first, let lastPar = sortedValues.last else {
            print("Trying to generate Y axis without datapoints, returning empty array")
            return []
        }

        guard lastPar >=~ first else { fatalError("Invalid range generating axis values") }

        let last = lastPar =~ first ? lastPar + 1 : lastPar

        /// The first axis value will be less than or equal to the first scalar value, aligned with the desired multiple
        var firstValue = first - (first.truncatingRemainder(dividingBy: multiple))
        /// The last axis value will be greater than or equal to the last scalar value, aligned with the desired multiple
        let remainder = last.truncatingRemainder(dividingBy: multiple)
        var lastValue = remainder == 0 ? last : last + (multiple - remainder)
        var segmentSize = multiple

        /// If there should be a padding segment added when a scalar value falls on the first or last axis value, adjust the first and last axis values
        if firstValue =~ first && addPaddingSegmentIfEdge {
            firstValue = firstValue - segmentSize
        }

        // do not allow the first label to be displayed as -0
        while firstValue < 0 && firstValue.rounded() == -0 {
            firstValue = firstValue - segmentSize
        }

        if lastValue =~ last && addPaddingSegmentIfEdge {
            lastValue = lastValue + segmentSize
        }

        let distance = lastValue - firstValue
        var currentMultiple = multiple
        var segmentCount = distance / currentMultiple
        var potentialSegmentValues = stride(from: firstValue, to: lastValue, by: currentMultiple)

        /// Find the optimal number of segments and segment width
        /// If the number of segments is greater than desired, make each segment wider
        /// ensure no label of -0 will be displayed on the axis
        while segmentCount > maxSegmentCount ||
            !potentialSegmentValues.filter({ $0 < 0 && $0.rounded() == -0 }).isEmpty
        {
            switch growth {
            case .linear:
                currentMultiple += multiple
            case .doubling:
                currentMultiple *= 2
            }
            segmentCount = distance / currentMultiple
            potentialSegmentValues = stride(from: firstValue, to: lastValue, by: currentMultiple)
        }
        segmentCount = ceil(segmentCount)

        /// Increase the number of segments until there are enough as desired
        while segmentCount < minSegmentCount {
            segmentCount += 1
        }
        segmentSize = currentMultiple

        /// Generate axis values from the first value, segment size and number of segments
        let offset = firstValue
        return (0...Int(segmentCount)).map { segment in
            var scalar = offset + (Double(segment) * segmentSize)
            // a value that could be displayed as 0 should truly be 0 to have the zero-line drawn correctly.
            if scalar != 0,
                scalar.rounded() == 0
            {
                scalar = 0
            }
            return scalar
        }
    }
    
    // This is the same as generateYAxisValuesWithChartPoints with the exception that the `firstValue`
    // calculation has been corrected such that the first axis value is truly less than or equal to the
    // first scalar value for negative values.
    public static func generateYAxisValuesWithChartPointsUpdated(chartValues: [Double], minSegmentCount: Double, maxSegmentCount: Double, multiple: Double = 10, addPaddingSegmentIfEdge: Bool) -> [Double] {
        let sortedValues = chartValues.sorted()

        guard let first = sortedValues.first, let lastPar = sortedValues.last else {
            print("Trying to generate Y axis without datapoints, returning empty array")
            return []
        }

        precondition(multiple > 0, "Invalid multiple: \(multiple)")

        guard lastPar >=~ first else { fatalError("Invalid range generating axis values") }

        let last = lastPar =~ first ? lastPar + 1 : lastPar

        // The first axis value will be less than or equal to the first scalar value, aligned with the desired multiple
        var firstValue = first - (multiple - abs(first.truncatingRemainder(dividingBy: multiple)))
        // The last axis value will be greater than or equal to the last scalar value, aligned with the desired multiple
        var lastValue = last + (abs(multiple - last).truncatingRemainder(dividingBy: multiple))
        var segmentSize = multiple

        // If there should be a padding segment added when a scalar value falls on the first or last axis value, adjust the first and last axis values
        if firstValue =~ first && addPaddingSegmentIfEdge {
            firstValue = firstValue - segmentSize
        }
        if lastValue =~ last && addPaddingSegmentIfEdge {
            lastValue = lastValue + segmentSize
        }
        
        let distance = lastValue - firstValue
        var currentMultiple = multiple
        var segmentCount = distance / currentMultiple

        // If the number of segments is greater than desired, make each segment wider
        while segmentCount > maxSegmentCount {
            currentMultiple *= 2
            segmentCount = distance / currentMultiple
        }
        segmentCount = ceil(segmentCount)

        // Increase the number of segments until there are enough as desired
        while segmentCount < minSegmentCount {
            segmentCount += 1
        }
        segmentSize = currentMultiple

        // Generate axis values from the first value, segment size and number of segments
        let offset = firstValue
        return (0...Int(segmentCount)).map { segment in
            offset + (Double(segment) * segmentSize)
        }
    }
}

infix operator =~: ComparisonPrecedence
infix operator >=~: ComparisonPrecedence

fileprivate func =~ (a: Double, b: Double) -> Bool {
    return fabs(a - b) < Double.ulpOfOne
}

fileprivate func >=~ (a: Double, b: Double) -> Bool {
    return a =~ b || a > b
}
