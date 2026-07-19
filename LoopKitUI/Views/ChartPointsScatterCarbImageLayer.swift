//
//  ChartPointsScatterCarbImageLayer.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/29/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI
import UIKit


/// The carb-entry image marker, used as a `PointMark` symbol on the glucose/carb chart.
///
/// Replaces the SwiftCharts `ChartPointsScatterCarbImageLayer`, which drew a caller-supplied
/// carb-entry image (or a favorite-food variant for entries sourced from favorite foods),
/// falling back to the "fork.knife.circle.fill" SF Symbol, tinted with the carb color and
/// aspect-fit within the item size. Size the symbol with `.frame(width:height:)`
/// (previously 16x16).
struct CarbEntrySymbol: View {
    /// The image to draw for a regular carb entry; falls back to "fork.knife.circle.fill"
    var carbEntryImage: UIImage?

    /// The image to draw when `isFavoriteFood` is true
    var carbEntryFavoriteFoodImage: UIImage?

    /// Marks a carb entry sourced from a favorite food (`ChartPoint.isFavoriteFood`)
    var isFavoriteFood: Bool = false

    /// The tint applied to the image (previously the layer's `itemFillColor`)
    var tintColor: Color

    private var image: Image {
        if isFavoriteFood, let carbEntryFavoriteFoodImage {
            return Image(uiImage: carbEntryFavoriteFoodImage)
        } else if let carbEntryImage {
            return Image(uiImage: carbEntryImage)
        } else {
            return Image(systemName: "fork.knife.circle.fill")
        }
    }

    var body: some View {
        image
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .foregroundColor(tintColor)
    }
}
