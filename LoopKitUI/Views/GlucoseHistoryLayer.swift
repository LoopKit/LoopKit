//
//  GlucoseHistoryLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 2/27/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI


/// The glucose-history dot, used as a `PointMark` symbol.
///
/// Replaces the SwiftCharts `GlucoseHistoryLayer`, a scatter-circles layer that drew every
/// glucose reading as a small filled circle and the most recent reading (the "current"
/// glucose) at a larger size. The previous call site used a 4x4 item size with an 8x8
/// current-item size, filled with the glucose tint color.
struct GlucoseHistorySymbol: View {
    /// Whether this point is the most recent reading, drawn at `currentItemSize`
    var isCurrent: Bool = false

    /// The diameter of a regular history dot
    var itemSize: CGFloat = 4

    /// The diameter of the most recent reading's dot
    var currentItemSize: CGFloat = 8

    /// The dot's fill color (previously the layer's `itemFillColor`)
    var fillColor: Color

    private var size: CGFloat {
        isCurrent ? currentItemSize : itemSize
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
    }
}
