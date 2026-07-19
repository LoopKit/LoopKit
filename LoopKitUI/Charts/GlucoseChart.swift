//
//  GlucoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
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
                    ChartPoint(date: nil, value: range.lowerBound.doubleValue(for: glucoseUnit)),
                    ChartPoint(date: nil, value: range.upperBound.doubleValue(for: glucoseUnit))
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

        return glucoseValues.map {
            return ChartPoint(
                date: $0.startDate,
                y: ChartValue(
                    scalar: $0.quantity.doubleValue(for: glucoseUnit),
                    unitString: unitString,
                    formatter: unitFormatter.numberFormatter
                )
            )
        }
    }
}
