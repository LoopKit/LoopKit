//
//  ChartPointsScatterBorderedCirclesLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftCharts

class ChartPointsScatterBorderedCirclesLayer<T: ChartPoint>: ChartPointsScatterCirclesLayer<T> {
    private let itemBorderColor: UIColor
    
    public init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float = 0,
        itemSize: CGSize,
        itemFillColor: UIColor,
        itemBorderColor: UIColor,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        self.itemBorderColor = itemBorderColor
        
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
    
    required convenience init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float = 0,
        itemSize: CGSize,
        itemFillColor: UIColor,
        optimized: Bool = false,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        self.init(
            xAxis: xAxis,
            yAxis: yAxis,
            chartPoints: chartPoints,
            displayDelay: displayDelay,
            itemSize: itemSize,
            itemFillColor: itemFillColor,
            itemBorderColor: UIColor.white,
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
        context.fillEllipse(in: CGRect(x: screenLoc.x - w / 2, y: screenLoc.y - h / 2, width: w, height: h))
        context.setStrokeColor(itemBorderColor.cgColor)
        context.setLineWidth(1.2)
        context.strokeEllipse(in: CGRect(x: screenLoc.x - w / 2, y: screenLoc.y - h / 2, width: w, height: h))
    }
}
