//
//  GlucoseCarbChart.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/26/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftCharts
import HealthKit
import UIKit
import LoopAlgorithm

public class GlucoseCarbChart: GlucoseChart, ChartProviding {

    public private(set) var glucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = glucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }
    
    public var carbEntries: [StoredCarbEntry] = []
    
    /// Image to display for each carb entry on x-axis of graph
    public var carbEntryImage: UIImage?
    /// Image to display for when carb entry is a favorite food
    public var carbEntryFavoriteFoodImage: UIImage?

    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?

    public private(set) var endDate: Date?
        
    private let yAxisStepSizeMGDLOverride: Double?
        
    private var maxYAxisSegmentCount: Double { 4 }
    
    private func updateEndDate(_ date: Date) {
        if endDate == nil || date > endDate! {
            self.endDate = date
        }
    }
    
    public init(yAxisStepSizeMGDLOverride: Double? = nil) {
        self.yAxisStepSizeMGDLOverride = yAxisStepSizeMGDLOverride
        super.init()
    }
}

extension GlucoseCarbChart {
    public func didReceiveMemoryWarning() {
        glucosePoints = []
        glucoseChartCache = nil
    }

    public func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection) -> Chart
    {
       let yAxisValues = determineYAxisValues(axisLabelSettings: axisLabelSettings)
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)
        
        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)

        let circles = ChartPointsScatterCirclesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucosePoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), itemFillColor: colors.glucoseTint, optimized: true)
        
        // Carb points are highlighted in green with a circle 22 points in size
        let carbPoints = generateCarbChartPoints(carbEntries, fixedYValue: yAxisValues.min(by: { $0.scalar < $1.scalar })?.scalar, overrideColor: colors.carbTint)
        let carbCircles = ChartPointsScatterCarbImageLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: carbPoints, displayDelay: 0, itemSize: CGSize(width: 16, height: 16), itemFillColor: colors.carbTint, carbEntryImage: carbEntryImage, carbEntryFavoriteFoodImage: carbEntryFavoriteFoodImage)

        if gestureRecognizer != nil {
            let highlightPoints = glucosePoints.mergeWithSortedArray(carbPoints)
            glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: highlightPoints,
                tintColor: colors.glucoseTint,
                allowOverridingTintColor: true,
                allowOverridingHighlightPointSize: true,
                highlightPointOffsetY: 8,
                gestureRecognizer: gestureRecognizer
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            xAxisLayer,
            yAxisLayer,
            glucoseChartCache?.highlightLayer,
            circles,
            carbCircles
        ]
        
        // Inset to allow for carb points on x-axis without clipping
        return Chart(
            frame: frame.insetBy(dx: 0, dy: -2),
            innerFrame: innerFrame.insetBy(dx: 0, dy: -8),
            settings: chartSettings,
            layers: layers.compactMap { $0 }
        )
    }
    
    private func determineYAxisValues(axisLabelSettings: ChartLabelSettings? = nil) -> [ChartAxisValue] {
        let points = [
            glucosePoints,
            glucoseDisplayRangePoints
        ].flatMap { $0 }

        let axisValueGenerator: ChartAxisValueStaticGenerator
        if let axisLabelSettings = axisLabelSettings {
            axisValueGenerator = { ChartAxisValueDouble($0, labelSettings: axisLabelSettings) }
        } else {
            axisValueGenerator = { ChartAxisValueDouble($0) }
        }
        
        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(chartPoints: points,
            minSegmentCount: 2,
            maxSegmentCount: maxYAxisSegmentCount,
            multiple: glucoseUnit == .milligramsPerDeciliter ? (yAxisStepSizeMGDLOverride ?? 25) : 1,
            axisValueGenerator: axisValueGenerator,
            addPaddingSegmentIfEdge: false
        )
        
        return yAxisValues
    }
    
    private func generateCarbChartPoints(_ carbEntries: [StoredCarbEntry], fixedYValue: Double?, overrideColor: UIColor) -> [ChartPoint] {
        guard let fixedYValue else { return [] }
        
        let carbFormatter = QuantityFormatter(for: .gram())
        carbFormatter.unitStyle = .short
        let unitString = carbFormatter.localizedUnitStringWithPlurality()
        let dateFormatter = DateFormatter(timeStyle: .short)
        
        return carbEntries.map { entry in
            ChartPoint(
                x: ChartAxisValueDate(date: entry.startDate, formatter: dateFormatter),
                y: ChartAxisValueCarbEntry(
                    carbQuantity: entry.amount,
                    fixedY: fixedYValue,
                    unitString: unitString,
                    formatter: carbFormatter.numberFormatter,
                    isFavoriteFood: entry.favoriteFoodID != nil,
                    overrideColor: overrideColor,
                    overrideHighlightPointSize: 22
                )
            )
        }
    }
}

extension GlucoseCarbChart {
    public func setGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        glucosePoints = glucosePointsFromValues(glucoseValues)
    }
}
