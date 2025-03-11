//
//  GlucoseHistoryLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 2/27/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftCharts

class GlucoseHistoryLayer<T: ChartPoint>: ChartPointsScatterCirclesLayer<T> {
    
    private let lastPoint: T?
    private let currentItemSize: CGSize
    
    public init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoints: [T],
        displayDelay: Float = 0,
        itemSize: CGSize,
        currentItemSize: CGSize,
        itemFillColor: UIColor,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        self.lastPoint = chartPoints.last
        self.currentItemSize = currentItemSize
        
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
        optimized: Bool = true,
        tapSettings: ChartPointsTapSettings<T>? = nil
    ) {
        self.init(
            xAxis: xAxis,
            yAxis: yAxis,
            chartPoints: chartPoints,
            displayDelay: displayDelay,
            itemSize: itemSize,
            currentItemSize: itemSize,
            itemFillColor: itemFillColor,
            tapSettings: tapSettings
        )
    }
    
    override open func drawChartPointModel(
        _ context: CGContext,
        chartPointModel: ChartPointLayerModel<T>,
        view: UIView
    ) {
        
        let isLastPoint = chartPointModel.chartPoint == lastPoint
        
        let w = isLastPoint ? currentItemSize.width : itemSize.width
        let h = isLastPoint ? currentItemSize.height : itemSize.height
        
        let screenLoc = modelLocToScreenLoc(x: chartPointModel.chartPoint.x.scalar, y: chartPointModel.chartPoint.y.scalar)
        
        context.setFillColor(itemFillColor.cgColor)
        context.fillEllipse(in: CGRect(x: screenLoc.x - w / 2, y: screenLoc.y - h / 2, width: w, height: h))
    }
}
