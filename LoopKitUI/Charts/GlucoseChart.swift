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
