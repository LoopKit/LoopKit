//
//  LegacyDoseChart.swift
//  LoopKitUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Charts
import Foundation
import LoopKit
import LoopAlgorithm
import SwiftUI
import UIKit

fileprivate struct LegacyDosePointsCache {
    let basal: [ChartPoint]
    let basalFill: [ChartPoint]
    let bolus: [ChartPoint]
    let highlight: [ChartPoint]
}

public class LegacyDoseChart: ChartProviding {
    public init() {
        doseEntries = []
    }

    public var doseEntries: [BasalRelativeDose] {
        didSet {
            pointsCache = nil
        }
    }

    private var pointsCache: LegacyDosePointsCache? {
        didSet {
            if let pointsCache = pointsCache {
                if let lastDate = pointsCache.highlight.last?.date {
                    endDate = lastDate
                }
            }
        }
    }

    private let doseDisplayRangeValues: [Double] = [0, 1]

    public private(set) var endDate: Date?

    private let gestureBridge = ChartGestureBridge()
}

public extension LegacyDoseChart {
    func didReceiveMemoryWarning() {
        pointsCache = nil
    }

    func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        guard #available(iOS 16.0, *) else {
            return UIView(frame: frame)
        }

        let integerFormatter = NumberFormatter.integer

        let points = generateDosePoints(startDate: context.xAxisModel.startDate)

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(
            chartValues: (points.basal + points.bolus).map { $0.y.scalar } + doseDisplayRangeValues,
            minSegmentCount: 2,
            maxSegmentCount: 3,
            multiple: log(2) / 2,
            addPaddingSegmentIfEdge: true)

        let insulinColor = Color(context.colors.insulinTint)
        let areaColor = Color(context.colors.insulinTint.withAlphaComponent(0.5))
        let basalPoints = points.basal.datedPoints
        let basalFillPoints = points.basalFill.datedPoints
        let bolusPoints = points.bolus.datedPoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            highlight = ChartHighlightSpec(points: points.highlight, tintColor: context.colors.insulinTint)
        } else {
            highlight = nil
        }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            yAxisLabelProvider: { integerFormatter.string(from: NSNumber(value: ChartLogScale.fromPlot($0))) ?? "" },
            highlight: highlight,
            highlightModel: gestureBridge.model
        ) {
            // The dose area
            ForEach(Array(basalFillPoints.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date!),
                    yStart: .value("Zero", 0),
                    yEnd: .value("Dose", point.y.scalar)
                )
                .foregroundStyle(areaColor)
            }

            // The dose line
            ForEach(Array(basalPoints.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date!),
                    y: .value("Dose", point.y.scalar),
                    series: .value("Series", "Basal")
                )
            }
            .lineStyle(ChartLineStyle.valueLine())
            .foregroundStyle(insulinColor)

            // 0-line
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(insulinColor)

            // The bolus markers
            ForEach(Array(bolusPoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Bolus", point.y.scalar)
                )
                .symbol {
                    DownTriangle()
                        .fill(insulinColor)
                        .frame(width: 12, height: 12)
                }
            }
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
    
    private func generateDosePoints(startDate: Date) -> LegacyDosePointsCache {
        
        guard pointsCache == nil else {
            return pointsCache!
        }

        let doseFormatter = NumberFormatter.dose

        var basalPoints = [ChartPoint]()
        var basalFillPoints = [ChartPoint]()
        var bolusPoints = [ChartPoint]()
        var highlightPoints = [ChartPoint]()
        
        for entry in doseEntries {
            let time = entry.endDate.timeIntervalSince(entry.startDate)

            if entry.type == .bolus && entry.netBasalUnits > 0 {
                let units = entry.volume
                let point = ChartPoint(
                    date: entry.startDate,
                    y: ChartValue(
                        scalar: ChartLogScale.toPlot(units),
                        actual: units,
                        unitString: "U",
                        formatter: doseFormatter
                    )
                )
                bolusPoints.append(point)
                highlightPoints.append(point)
            } else if time > 0 {
                // TODO: Display the DateInterval
                let startX = max(startDate, entry.startDate)
                let endX = entry.endDate
                let rate = entry.netBasalUnits / time.hours
                let value = ChartValue(
                    scalar: ChartLogScale.toPlot(rate),
                    actual: rate,
                    unitString: "U/hour",
                    formatter: doseFormatter
                )
                let zero = ChartValue(scalar: 0, label: "")

                let valuePoints: [ChartPoint]

                if abs(rate) > .ulpOfOne {
                    valuePoints = [
                        ChartPoint(date: startX, y: value),
                        ChartPoint(date: endX, y: value)
                    ]
                } else {
                    valuePoints = []
                }
                
                
                basalFillPoints += [ChartPoint(date: startX, y: zero)] + valuePoints + [ChartPoint(date: endX, y: zero)]
                if entry.startDate > startDate {
                    basalPoints += [ChartPoint(date: startX, y: zero)]
                }
                basalPoints += valuePoints + [ChartPoint(date: endX, y: zero)]

                highlightPoints += valuePoints
            }
        }
        
        let pointsCache = LegacyDosePointsCache(basal: basalPoints, basalFill: basalFillPoints, bolus: bolusPoints, highlight: highlightPoints)
        self.pointsCache = pointsCache
        return pointsCache
    }
}
