//
//  DoseChart.swift
//  LoopUI
//
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Charts
import Foundation
import LoopKit
import LoopAlgorithm
import SwiftUI
import UIKit

fileprivate struct DosePointsCache {
    let autoBolus: [ChartPoint]
    let manualBolus: [ChartPoint]
}

public class DoseChart: ChartProviding {
    public init() {
        doseEntries = []
    }

    public var doseEntries: [DoseEntry] {
        didSet {
            pointsCache = nil
        }
    }

    private var pointsCache: DosePointsCache? {
        didSet {
            if let pointsCache = pointsCache, let lastDate = pointsCache.autoBolus.last?.date {
                endDate = lastDate
            }
        }
    }

    public private(set) var endDate: Date?

    private let gestureBridge = ChartGestureBridge()
}

public extension DoseChart {
    func didReceiveMemoryWarning() {
        pointsCache = nil
    }

    func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        var chartSettings = context.chartSettings
        chartSettings.labelsToAxisSpacingX = -10
        let context = ChartGenerationContext(
            xAxisModel: context.xAxisModel,
            colors: context.colors,
            chartSettings: chartSettings,
            axisLabelFont: context.axisLabelFont,
            labelsWidthY: context.labelsWidthY,
            gestureRecognizer: context.gestureRecognizer,
            traitCollection: context.traitCollection,
            highlightLabelOffsetY: context.highlightLabelOffsetY
        )

        let points = generateDosePoints(startDate: context.xAxisModel.startDate)

        let yAxisValues: [Double] = [0, 1, 2]

        let insulinColor = Color(context.colors.insulinTint)
        let autoBolusPoints = points.autoBolus.datedPoints
        let manualBolusPoints = points.manualBolus.datedPoints

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            yAxisLabelProvider: { _ in "" },
            hidesAxes: true,
            highlight: nil,
            highlightModel: gestureBridge.model
        ) {
            // Manual bolus markers
            ForEach(Array(manualBolusPoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Bolus", point.y.scalar)
                )
                .symbol {
                    ManualBolusDoseSymbol(size: 18)
                }
            }

            // Automatic bolus markers
            ForEach(Array(autoBolusPoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Bolus", point.y.scalar)
                )
                .symbol {
                    BorderedCircle(fillColor: insulinColor)
                        .frame(width: 12, height: 12)
                }
            }
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
    
    private func generateDosePoints(startDate: Date) -> DosePointsCache {
        guard pointsCache == nil else {
            return pointsCache!
        }

        var autoBolusPoints = [ChartPoint]()
        var manualBolusPoints = [ChartPoint]()
        
        for entry in doseEntries {
            if entry.type == .bolus && entry.netBasalUnits > 0 {
                if entry.automatic == true {
                    autoBolusPoints.append(ChartPoint(date: entry.startDate, value: 0.5))
                } else {
                    manualBolusPoints.append(ChartPoint(date: entry.startDate, value: 1.5))
                }
            }
        }
        
        let pointsCache = DosePointsCache(autoBolus: autoBolusPoints, manualBolus: manualBolusPoints)
        self.pointsCache = pointsCache
        return pointsCache
    }
}
