//
//  ChartAxisValueDoubleUnit.swift
//  LoopKitUI
//
//  Created by Nate Racklyeft on 7/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopAlgorithm
import LoopKit
import UIKit


/// A formatted value plotted on a chart.
///
/// `scalar` is the value in plot space (for most charts this is the actual value; the dose
/// chart plots values in a signed-log space). `label` is the full localized display text
/// (e.g. "115 mg/dL"); `valueLabel`/`unitLabel` carry the split forms used by the styled
/// highlight annotation.
public struct ChartValue: Equatable, CustomStringConvertible {
    public let scalar: Double
    public let label: String
    public let valueLabel: String?
    public let unitLabel: String?

    public init(scalar: Double, label: String, valueLabel: String? = nil, unitLabel: String? = nil) {
        self.scalar = scalar
        self.label = label
        self.valueLabel = valueLabel
        self.unitLabel = unitLabel
    }

    public init(scalar: Double, unitString: String? = nil, formatter: NumberFormatter) {
        self.init(scalar: scalar, actual: scalar, unitString: unitString, formatter: formatter)
    }

    public init(scalar: Double, actual: Double, unitString: String? = nil, formatter: NumberFormatter) {
        let valueText = formatter.string(from: NSNumber(value: actual)) ?? ""

        if let unitString = unitString {
            self.init(
                scalar: scalar,
                label: formatter.string(from: actual, unit: unitString) ?? "",
                valueLabel: valueText,
                unitLabel: unitString
            )
        } else {
            self.init(scalar: scalar, label: valueText, valueLabel: valueText, unitLabel: nil)
        }
    }

    public var description: String {
        return label
    }
}


/// A single date-stamped point charted by one of the Loop charts.
public struct ChartPoint: Equatable {
    /// The date of the value, or nil for points that only participate in axis scaling.
    public let date: Date?

    public let y: ChartValue

    /// Overrides the highlight dot/label tint for this point (e.g. carb entry markers)
    public let overrideColor: UIColor?

    /// Overrides the highlight dot diameter for this point
    public let overrideHighlightPointSize: CGFloat?

    /// Marks a carb entry sourced from a favorite food
    public let isFavoriteFood: Bool?

    public init(date: Date?, y: ChartValue, overrideColor: UIColor? = nil, overrideHighlightPointSize: CGFloat? = nil, isFavoriteFood: Bool? = nil) {
        self.date = date
        self.y = y
        self.overrideColor = overrideColor
        self.overrideHighlightPointSize = overrideHighlightPointSize
        self.isFavoriteFood = isFavoriteFood
    }

    public init(date: Date?, value: Double) {
        self.init(date: date, y: ChartValue(scalar: value, label: ""))
    }
}

extension ChartPoint: TimelineValue {
    public var startDate: Date {
        return date ?? Date.distantPast
    }
}
