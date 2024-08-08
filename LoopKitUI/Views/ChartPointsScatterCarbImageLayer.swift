//
//  ChartPointsScatterCarbImageLayer.swift
//  LoopKit
//
//  Created by Noah Brauner on 7/29/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftCharts
import CoreGraphics
import UIKit

class ChartPointsScatterCarbImageLayer<T: ChartPoint>: ChartPointsScatterLayer<T> {
    private var carbEntryImage: UIImage?
    private var carbEntryFavoriteFoodImage: UIImage?
    
    required init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float,
        itemSize: CGSize,
        itemFillColor: UIColor,
        optimized: Bool = false,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        // optimized must be set to false because `generateCGLayer` isn't public and can't be overridden
        super.init(
            xAxis: xAxis,
            yAxis: yAxis,
            chartPoints: chartPoints,
            displayDelay: displayDelay,
            itemSize: itemSize,
            itemFillColor: itemFillColor,
            optimized: false,
            tapSettings: tapSettings
        )
    }
    
    required init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float,
        itemSize: CGSize,
        itemFillColor: UIColor,
        tapSettings: ChartPointsTapSettings<T>? = nil,
        carbEntryImage: UIImage? = nil,
        carbEntryFavoriteFoodImage: UIImage? = nil
    ) {
        self.carbEntryImage = carbEntryImage
        self.carbEntryFavoriteFoodImage = carbEntryFavoriteFoodImage
        
        super.init(
            xAxis: xAxis,
            yAxis: yAxis,
            chartPoints: chartPoints,
            displayDelay: displayDelay,
            itemSize: itemSize,
            itemFillColor: itemFillColor,
            optimized: false,
            tapSettings: tapSettings
        )
    }

    override func drawChartPointModel(_ context: CGContext, chartPointModel: ChartPointLayerModel<T>, view: UIView) {
        let point = chartPointModel.chartPoint
        var image = UIImage()
        
        if point.isFavoriteFood == true, let carbEntryFavoriteFoodImage {
            image = carbEntryFavoriteFoodImage
        } else if let carbEntryImage {
            image = carbEntryImage
        } else if let defaultImage = UIImage(systemName: "fork.knife.circle.fill") {
            image = defaultImage
        }
        
        let tintedImage = image.withTintColor(self.itemFillColor, renderingMode: .alwaysOriginal)
        
        let w = self.itemSize.width
        let h = self.itemSize.height
        // Set the position where the image will be drawn
        let x = chartPointModel.screenLoc.x - w / 2
        let y = chartPointModel.screenLoc.y - h / 2
                
        let imageAspectRatio = image.size.width / image.size.height
        let containerAspectRatio = w / h
        var drawRect: CGRect
        
        if imageAspectRatio > containerAspectRatio {
            // Image is wider than container: use container weight and regular x position, scale height and correct y-position
            let drawHeight = w / imageAspectRatio
            let drawY = y + (h - drawHeight) / 2
            drawRect = CGRect(x: x, y: drawY, width: w, height: drawHeight)
        } else {
            // Image is narrower than container: use container height and regular y position, scale width and correct x-position
            let drawWidth = h * imageAspectRatio
            let drawX = x + (w - drawWidth) / 2
            drawRect = CGRect(x: drawX, y: y, width: drawWidth, height: h)
        }
        
        // Draw the UIImage into the CGContext
        UIGraphicsPushContext(context)
        tintedImage.draw(in: drawRect)
        UIGraphicsPopContext()
    }
}
