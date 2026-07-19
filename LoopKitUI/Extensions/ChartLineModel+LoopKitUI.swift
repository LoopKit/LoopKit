//
//  ChartLineModel.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Shared stroke styles for the Loop charts.
public enum ChartLineStyle {
    /// The dashed style used for prediction lines
    public static func predictionLine(width: CGFloat) -> StrokeStyle {
        return StrokeStyle(lineWidth: width, dash: [6, 5])
    }

    /// The solid style used for value lines (IOB, COB, basal)
    public static func valueLine(width: CGFloat = 2) -> StrokeStyle {
        return StrokeStyle(lineWidth: width)
    }
}
