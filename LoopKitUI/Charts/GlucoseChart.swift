//
//  GlucoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import SwiftCharts
import LoopAlgorithm

open class GlucoseChart {
    public init() {
    }

    public var glucoseUnit: LoopUnit = .milligramsPerDeciliter {
        didSet {
            if glucoseUnit != oldValue {
                // Regenerate the glucose display points
                let oldRange = glucoseDisplayRange
                glucoseDisplayRange = oldRange
            }
        }
    }

    public var glucoseDisplayRange: ClosedRange<LoopQuantity>? {
        didSet {
            if let range = glucoseDisplayRange {
                glucoseDisplayRangePoints = [
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.lowerBound.doubleValue(for: glucoseUnit))),
                    ChartPoint(x: ChartAxisValue(scalar: 0), y: ChartAxisValueDouble(range.upperBound.doubleValue(for: glucoseUnit)))
                ]
            } else {
                glucoseDisplayRangePoints = []
            }
        }
    }

    public private(set) var glucoseDisplayRangePoints: [ChartPoint] = []

    public var usesFixedScale = false

    /// Y-axis gridlines for the fixed scale. The first is the chart floor and is left unlabeled.
    public static func fixedScaleAxisValues(for unit: LoopUnit) -> [Double] {
        unit == .milligramsPerDeciliter ? [40, 100, 200, 300, 400] : [2, 6, 10, 14, 18, 22]
    }

    func fixedYAxisValues(axisValueGenerator: ChartAxisValueStaticGenerator) -> [ChartAxisValue]? {
        guard usesFixedScale else { return nil }
        let values = Self.fixedScaleAxisValues(for: glucoseUnit)
        return [ChartAxisValueString("", order: Int(values[0]))] + values.dropFirst().map(axisValueGenerator)
    }

    public func glucosePointsFromValues(_ glucoseValues: [GlucoseValue]) -> [ChartPoint] {
        let unitFormatter = QuantityFormatter(for: glucoseUnit)
        unitFormatter.unitStyle = .short
        let unitString = unitFormatter.localizedUnitStringWithPlurality()
        let dateFormatter = DateFormatter(timeStyle: .short)

        return glucoseValues.map {
            let sample = $0 as? GlucoseSampleValue
            let pointType: ChartPoint.Type = sample?.wasUserEntered == true && sample?.isDisplayOnly == false ? ManualGlucoseChartPoint.self : ChartPoint.self
            return pointType.init(
                x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: glucoseUnit), unitString: unitString, formatter: unitFormatter.numberFormatter)
            )
        }
    }
}

/// A glucose value entered by hand, such as a fingerstick or calibration.
final class ManualGlucoseChartPoint: ChartPoint {}
