//
//  DoseChart.swift
//  LoopUI
//
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftCharts
import UIKit
import LoopAlgorithm

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
            if let pointsCache = pointsCache, let lastDate = pointsCache.autoBolus.last?.x as? ChartAxisValueDate {
                endDate = lastDate.date
            }
        }
    }

    /// The minimum range to display for insulin values.
    private let doseDisplayRangePoints: [ChartPoint] = [0, 1].map {
        return ChartPoint(
            x: ChartAxisValue(scalar: 0),
            y: ChartAxisValueInt($0)
        )
    }

    public private(set) var endDate: Date?
}

public extension DoseChart {
    func didReceiveMemoryWarning() {
        pointsCache = nil
    }

    func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection, highlightLabelOffsetY: CGFloat) -> Chart
    {
        var chartSettings = chartSettings
        chartSettings.labelsToAxisSpacingX = -10
        
        let startDate = ChartAxisValueDate.dateFromScalar(xAxisValues.first!.scalar)
        
        let points = generateDosePoints(startDate: startDate)
        
        let yAxisValues: [ChartAxisValue] = [
            ChartAxisValue(scalar: 0),
            ChartAxisValue(scalar: 1),
            ChartAxisValue(scalar: 2)
        ]
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // Manual bolus points
        let manualBolusPointSize: Double = 18
        let manualBolusLayer: ManualBolusDoseChartLayer<ChartPoint>?
        
        if points.manualBolus.count > 0 {
            manualBolusLayer = ManualBolusDoseChartLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: points.manualBolus, displayDelay: 0, itemSize: CGSize(width: manualBolusPointSize, height: manualBolusPointSize), itemFillColor: colors.insulinTint)
        } else {
            manualBolusLayer = nil
        }

        // Auto bolus points
        let autoBolusPointSize: Double = 12
        let autoBolusLayer: ChartPointsScatterCirclesLayer<ChartPoint>?
        
        if points.autoBolus.count > 0 {
            autoBolusLayer = ChartPointsScatterBorderedCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: points.autoBolus, displayDelay: 0, itemSize: CGSize(width: autoBolusPointSize, height: autoBolusPointSize), itemFillColor: colors.insulinTint)
        } else {
            autoBolusLayer = nil
        }

        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)

        let layers: [ChartLayer?] = [
            gridLayer,
            manualBolusLayer,
            autoBolusLayer
        ]

        return Chart(frame: frame, innerFrame: innerFrame, settings: chartSettings, layers: layers.compactMap { $0 })
    }
    
    private func generateDosePoints(startDate: Date) -> DosePointsCache {
        guard pointsCache == nil else {
            return pointsCache!
        }
        
        let dateFormatter = DateFormatter(timeStyle: .short)

        var autoBolusPoints = [ChartPoint]()
        var manualBolusPoints = [ChartPoint]()
        
        for entry in doseEntries {
            if entry.type == .bolus && entry.netBasalUnits > 0 {
                let x = ChartAxisValueDate(date: entry.startDate, formatter: dateFormatter)

                if entry.automatic == true {
                    let point = ChartPoint(x: x, y: ChartAxisValue(scalar: 0.5))
                    autoBolusPoints.append(point)
                } else {
                    let point = ChartPoint(x: x, y: ChartAxisValue(scalar: 1.5))
                    manualBolusPoints.append(point)
                }
            }
        }
        
        let pointsCache = DosePointsCache(autoBolus: autoBolusPoints, manualBolus: manualBolusPoints)
        self.pointsCache = pointsCache
        return pointsCache
    }
}
