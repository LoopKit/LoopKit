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
    public let doseTint: UIColor

    public init(axisLine: UIColor, axisLabel: UIColor, grid: UIColor, glucoseTint: UIColor, doseTint: UIColor) {
        self.axisLine = axisLine
        self.axisLabel = axisLabel
        self.grid = grid
        self.glucoseTint = glucoseTint
        self.doseTint = doseTint
    }
    
    static var `default`: ChartColorPalette {
        return ChartColorPalette(axisLine: .axisLineColor, axisLabel: .axisLabelColor, grid: .gridColor, glucoseTint: .glucoseTintColor, doseTint: .doseTintColor)
    }
}
