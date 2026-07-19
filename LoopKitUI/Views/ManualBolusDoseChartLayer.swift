//
//  ManualBolusDoseChartLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit


/// The manual-bolus glyph on the dose chart, used as a `PointMark` symbol.
///
/// Replaces the SwiftCharts `ManualBolusDoseChartLayer`, which drew the app's
/// "dose-chart-bolus-icon" asset (from `Bundle.main`) stretched to 0.6875x the item width
/// at the full item height (previously an 18pt item size).
struct ManualBolusDoseSymbol: View {
    /// The marker's item size; the icon is drawn at 0.6875x this width and the full height
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = UIImage(named: "dose-chart-bolus-icon", in: .main, with: nil) {
                Image(uiImage: image)
                    .resizable()
            }
        }
        .frame(width: size * 0.6875, height: size)
    }
}
