//
//  ManualBolusDoseChartLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftCharts

class ManualBolusDoseChartLayer<T: ChartPoint>: ChartPointsScatterLayer<T> {
    
    required convenience init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float = 0,
        itemSize: CGSize,
        itemFillColor: UIColor,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        self.init(
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
    
    override open func drawChartPointModel(
        _ context: CGContext,
        chartPointModel: ChartPointLayerModel<T>,
        view: UIView
    ) {
        let w = itemSize.width
        let h = itemSize.height
        
        let screenLoc = modelLocToScreenLoc(x: chartPointModel.chartPoint.x.scalar, y: chartPointModel.chartPoint.y.scalar)
        
        context.setFillColor(itemFillColor.cgColor)
        
        if let image = UIImage(named: "bolus", in: .main, with: nil)?.cgImage {
            let rect = CGRect(x: screenLoc.x - w / 2, y: screenLoc.y - h / 2, width: w, height: h)
            context.saveGState()
            context.translateBy(x: rect.origin.x, y: rect.origin.y)
            context.translateBy(x: rect.width / 2, y: rect.height / 2)
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: -rect.width / 2, y: -rect.height / 2)
            let drawRect = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
            context.clip(to: drawRect, mask: image)
            context.fill(drawRect)
            context.restoreGState()
        }
    }
}
