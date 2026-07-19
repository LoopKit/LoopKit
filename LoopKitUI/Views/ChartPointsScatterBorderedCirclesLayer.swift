//
//  ChartPointsScatterBorderedCirclesLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit


/// A filled circle with a contrasting border stroke, used as a `PointMark` symbol to mark
/// automatic boluses on the dose chart.
///
/// Replaces the SwiftCharts `ChartPointsScatterBorderedCirclesLayer`, which filled an
/// ellipse with the item color and stroked its edge with the border color at a 1.2pt line
/// width (defaulting to `.systemBackground`). Size the symbol with `.frame(width:height:)`.
struct BorderedCircle: View {
    var fillColor: Color
    var borderColor: Color = Color(UIColor.systemBackground)
    var borderWidth: CGFloat = 1.2

    var body: some View {
        Circle()
            .fill(fillColor)
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}
