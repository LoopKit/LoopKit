//
//  ChartColorPalette.swift
//  LoopKitUI
//
//  Created by Bharat Mediratta on 3/29/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import UIKit

/// A palette of colors for displaying charts
public struct ChartColorPalette {
    public let axisLine: UIColor
    public let axisLabel: UIColor
    public let grid: UIColor
    public let glucoseTint: UIColor
    public let insulinTint: UIColor

    public init(axisLine: UIColor, axisLabel: UIColor, grid: UIColor, glucoseTint: UIColor, insulinTint: UIColor) {
        self.axisLine = axisLine
        self.axisLabel = axisLabel
        self.grid = grid
        self.glucoseTint = glucoseTint
        self.insulinTint = insulinTint
    }
}
