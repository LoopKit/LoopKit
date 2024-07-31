//
//  ChartAxisValueDoubleCarbEntry.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/29/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftCharts

/// Allows for carb entry icons to be plotted in a horizontal line at y-value `fixedY` independantly of their carb quantity values.
/// Upon highlight, label will display the carb quantity `carbQuantity` formatted by `formatter`.
/// `overrideColor` and `overrideHighlightPointDiameter` allow for overriding the color and size of point in the highlight layer
public final class ChartAxisValueCarbEntry: ChartAxisValueDouble {
    let carbQuantity: Double
    let unitString: String
    let isFavoriteFood: Bool
    let overrideColor: UIColor?
    let overrideHighlightPointSize: CGFloat?
    
    public init(carbQuantity: Double, fixedY: Double, unitString: String, formatter: NumberFormatter, isFavoriteFood: Bool, overrideColor: UIColor? = nil, overrideHighlightPointSize: CGFloat? = nil) {
        self.carbQuantity = carbQuantity
        self.unitString = unitString
        self.isFavoriteFood = isFavoriteFood
        self.overrideColor = overrideColor
        self.overrideHighlightPointSize = overrideHighlightPointSize
        
        super.init(fixedY, formatter: formatter)
    }

    override public var description: String {
        return formatter.string(from: carbQuantity, unit: unitString) ?? ""
    }
}

extension ChartPoint {
    var isFavoriteFood: Bool? {
        if let point = y as? ChartAxisValueCarbEntry {
            return point.isFavoriteFood
        } else {
            return nil
        }
    }
    
    var overrideColor: UIColor? {
        if let point = y as? ChartAxisValueCarbEntry {
            return point.overrideColor
        } else {
            return nil
        }
    }
    
    var overrideHighlightPointSize: CGFloat? {
        if let point = y as? ChartAxisValueCarbEntry {
            return point.overrideHighlightPointSize
        } else {
            return nil
        }
    }
}
