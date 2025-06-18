//
//  ManualBolusDoseChartLayer.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftCharts
import SwiftUI

// Generated using [SVG-to-SwiftUI](https://svg-to-swiftui.quassum.com) from the `bolus` asset
struct BolusIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let newRect = self.rect(in: rect)
        let width = newRect.size.width
        let height = newRect.size.height

        var path = Path()
        
        path.move(
            to: CGPoint(
                x: 0.08052 * width,
                y: 0.00586 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.91357 * width,
                y: 0.00586 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.98112 * width,
                y: 0.08816 * height
            ),
            control1: CGPoint(
                x: 0.9771 * width,
                y: 0.00586 * height
            ),
            control2: CGPoint(
                x: 1.01569 * width,
                y: 0.05235 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.5654 * width,
                y: 0.52317 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.4295 * width,
                y: 0.52317 * height
            ),
            control1: CGPoint(
                x: 0.53323 * width,
                y: 0.55631 * height
            ),
            control2: CGPoint(
                x: 0.46086 * width,
                y: 0.55631 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.01298 * width,
                y: 0.08816 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.08052 * width,
                y: 0.00586 * height
            ),
            control1: CGPoint(
                x: -0.0216 * width,
                y: 0.05235 * height
            ),
            control2: CGPoint(
                x: 0.017 * width,
                y: 0.00586 * height
            )
        )
        path.closeSubpath()
        path.move(
            to: CGPoint(
                x: 0.98112 * width,
                y: 0.51569 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.91357 * width,
                y: 0.43339 * height
            ),
            control1: CGPoint(
                x: 1.01569 * width,
                y: 0.47989 * height
            ),
            control2: CGPoint(
                x: 0.9771 * width,
                y: 0.43339 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.85551 * width,
                y: 0.43337 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.5654 * width,
                y: 0.73694 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.4295 * width,
                y: 0.73694 * height
            ),
            control1: CGPoint(
                x: 0.53323 * width,
                y: 0.77007 * height
            ),
            control2: CGPoint(
                x: 0.46086 * width,
                y: 0.77007 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.13887 * width,
                y: 0.43337 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.08052 * width,
                y: 0.43339 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.01298 * width,
                y: 0.51569 * height
            ),
            control1: CGPoint(
                x: 0.017 * width,
                y: 0.43339 * height
            ),
            control2: CGPoint(
                x: -0.0216 * width,
                y: 0.47989 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.4295 * width,
                y: 0.95071 * height
            )
        )
        path.addCurve(
            to: CGPoint(
                x: 0.5654 * width,
                y: 0.95071 * height
            ),
            control1: CGPoint(
                x: 0.46086 * width,
                y: 0.98384 * height
            ),
            control2: CGPoint(
                x: 0.53323 * width,
                y: 0.98384 * height
            )
        )
        path.addLine(
            to: CGPoint(
                x: 0.98112 * width,
                y: 0.51569 * height
            )
        )
        path.closeSubpath()
        return path
    }
    
    private func rect(in boundingRect: CGRect) -> CGRect {
        return CGRect(
            origin: boundingRect.origin,
            size: CGSize(
                width: boundingRect.width * 0.6875,
                height: boundingRect.height
            )
        )
    }
}

class ManualBolusDoseChartLayer<T: ChartPoint>: ChartPointsScatterLayer<T> {
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
            itemBorderColor: .systemBackground,
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
        
        let screenLoc = modelLocToScreenLoc(
            x: chartPointModel.chartPoint.x.scalar,
            y: chartPointModel.chartPoint.y.scalar
        )
        
        let boundingRect = CGRect(x: screenLoc.x - w / 2, y: screenLoc.y - h / 2, width: w, height: h)
        
        let bolusPath = BolusIcon().path(in: boundingRect).cgPath

        context.saveGState()
        
        context.translateBy(x: boundingRect.minX + 2.4, y: boundingRect.minY)

        let strokedPath = bolusPath.copy(strokingWithWidth: 2.4, lineCap: .round, lineJoin: .bevel, miterLimit: 2)
        
        context.addPath(strokedPath)
        context.setFillColor(itemBorderColor.cgColor)
        context.fillPath()

        context.addPath(bolusPath)
        context.setFillColor(itemFillColor.cgColor)
        context.fillPath()
        
        context.restoreGState()
    }
}
