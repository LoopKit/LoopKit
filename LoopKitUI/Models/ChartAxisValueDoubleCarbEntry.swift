//
//  ChartAxisValueDoubleCarbEntry.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/29/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import UIKit

extension ChartPoint {
    /// A carb-entry marker plotted in a horizontal line at `fixedY` independently of its
    /// carb quantity. When highlighted, the label displays the formatted carb quantity,
    /// and the marker's color and highlight-dot size can be overridden per entry.
    static func carbEntry(
        date: Date,
        carbQuantity: Double,
        fixedY: Double,
        unitString: String,
        formatter: NumberFormatter,
        isFavoriteFood: Bool,
        overrideColor: UIColor? = nil,
        overrideHighlightPointSize: CGFloat? = nil
    ) -> ChartPoint {
        let valueText = formatter.string(from: NSNumber(value: carbQuantity)) ?? ""
        return ChartPoint(
            date: date,
            y: ChartValue(
                scalar: fixedY,
                label: formatter.string(from: carbQuantity, unit: unitString) ?? "",
                valueLabel: valueText,
                unitLabel: unitString
            ),
            overrideColor: overrideColor,
            overrideHighlightPointSize: overrideHighlightPointSize,
            isFavoriteFood: isFavoriteFood
        )
    }
}
