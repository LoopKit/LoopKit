//
//  LoopUIColorPalette.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 1/14/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct LoopUIColorPalette {
    public let guidanceColors: GuidanceColors
    public let carbTintColor: Color
    public let glucoseTintColor: Color
    public let insulinTintColor: Color
    public let chartColorPalette: ChartColorPalette

    public init(guidanceColors: GuidanceColors, carbTintColor: Color, glucoseTintColor: Color, insulinTintColor: Color, chartColorPalette: ChartColorPalette) {
        self.guidanceColors = guidanceColors
        self.carbTintColor = carbTintColor
        self.glucoseTintColor = glucoseTintColor
        self.insulinTintColor = insulinTintColor
        self.chartColorPalette = chartColorPalette
    }
}
