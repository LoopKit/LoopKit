//
//  PredictedGlucoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftCharts
import UIKit
import LoopAlgorithm

public class PredictedGlucoseChart: GlucoseChart, ChartProviding {

    public private(set) var glucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = glucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }

    /// The chart points for predicted glucose
    public private(set) var predictedGlucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = predictedGlucosePoints.last?.x as? ChartAxisValueDate {
                updateEndDate(lastDate.date)
            }
        }
    }

    /// The chart points for alternate predicted glucose
    public private(set) var alternatePredictedGlucosePoints: [ChartPoint]?

    public var targetGlucoseSchedule: GlucoseRangeSchedule? {
        didSet {
            targetGlucosePoints = []
        }
    }

    public var preMealOverride: TemporaryScheduleOverride?

    public var scheduleOverride: TemporaryScheduleOverride?

    private var targetGlucosePoints = [TargetChartBar]()

    private var glucoseChartCache: ChartPointsTouchHighlightLayerViewCache?

    public private(set) var endDate: Date?

    private var predictedGlucoseSoftBounds: PredictedGlucoseBounds?
    
    private let yAxisStepSizeMGDLOverride: Double?
        
    private var maxYAxisSegmentCount: Double {
        // when a glucose value is below the predicted glucose minimum soft bound, allow for more y-axis segments
        return glucoseValueBelowSoftBoundsMinimum() ? 5 : 4
    }
    
    private func updateEndDate(_ date: Date) {
        if endDate == nil || date > endDate! {
            self.endDate = date
        }
    }
    
    public init(predictedGlucoseBounds: PredictedGlucoseBounds? = nil,
                yAxisStepSizeMGDLOverride: Double? = nil) {
        self.predictedGlucoseSoftBounds = predictedGlucoseBounds
        self.yAxisStepSizeMGDLOverride = yAxisStepSizeMGDLOverride
        super.init()
    }
}

extension PredictedGlucoseChart {
    public func didReceiveMemoryWarning() {
        glucosePoints = []
        predictedGlucosePoints = []
        alternatePredictedGlucosePoints = nil
        targetGlucosePoints = [TargetChartBar]()

        glucoseChartCache = nil
    }

    public func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection, highlightLabelOffsetY: CGFloat) -> Chart
    {
        if targetGlucosePoints.isEmpty, xAxisValues.count > 1, let schedule = targetGlucoseSchedule {

            // TODO: This only considers one override: pre-meal or an active override. ChartPoint.barsForGlucoseRangeSchedule needs to accept list of overridden ranges.
            let potentialOverride = (preMealOverride?.isActive() ?? false) ? preMealOverride : (scheduleOverride?.isActive() ?? false) ? scheduleOverride : nil
            targetGlucosePoints = ChartPoint.barsForGlucoseRangeSchedule(schedule, unit: glucoseUnit, xAxisValues: xAxisValues, considering: potentialOverride)
        }
        
        let yAxisValues = determineYAxisValues(axisLabelSettings: axisLabelSettings)
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)

        // The glucose targets
        let targetFill = colors.glucoseTint.withAlphaComponent(0.2)
        let overrideFill: UIColor = colors.presetTint.withAlphaComponent(0.6)
        let fills =
            targetGlucosePoints.map {
                if $0.isOverride {
                    return ChartPointsFill(
                        chartPoints: $0.points,
                        fillColor: overrideFill,
                        createContainerPoints: false)
                } else {
                    return ChartPointsFill(
                        chartPoints: $0.points,
                        fillColor: targetFill,
                        createContainerPoints: false)
                }
            }
        
        let targetsLayer = ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: fills
        )

        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)

        let circles = GlucoseHistoryLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: glucosePoints, displayDelay: 0, itemSize: CGSize(width: 4, height: 4), currentItemSize: CGSize(width: 8, height: 8), itemFillColor: colors.glucoseTint)

        var alternatePrediction: ChartLayer?

        if let altPoints = alternatePredictedGlucosePoints, altPoints.count > 1 {

            let lineModel = ChartLineModel.predictionLine(points: altPoints, color: colors.glucoseTint, width: 2)

            alternatePrediction = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])
        }

        var prediction: ChartLayer?

        if predictedGlucosePoints.count > 1 {
            let lineColor = (alternatePrediction == nil) ? colors.glucoseTint : UIColor.secondaryLabel

            let lineModel = ChartLineModel.predictionLine(
                points: predictedGlucosePoints,
                color: lineColor,
                width: 1
            )

            prediction = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])
        }

        if gestureRecognizer != nil {
            glucoseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: glucosePoints + (alternatePredictedGlucosePoints ?? predictedGlucosePoints),
                tintColor: colors.glucoseTint,
                highlightLabelOffsetY: highlightLabelOffsetY,
                gestureRecognizer: gestureRecognizer
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            targetsLayer,
            xAxisLayer,
            yAxisLayer,
            glucoseChartCache?.highlightLayer,
            prediction,
            alternatePrediction,
            circles
        ]

        return Chart(
            frame: frame,
            innerFrame: innerFrame,
            settings: chartSettings,
            layers: layers.compactMap { $0 }
        )
    }
    
    private func determineYAxisValues(axisLabelSettings: ChartLabelSettings? = nil) -> [ChartAxisValue] {
        let points = [
            glucosePoints, predictedGlucosePoints,
            targetGlucosePoints.flatMap { $0.points },
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
}

extension PredictedGlucoseChart {
    public func setGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        glucosePoints = glucosePointsFromValues(glucoseValues)
    }

    public func setPredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        let clampedPredicatedGlucoseValues = clampPredictedGlucoseValues(glucoseValues)
        predictedGlucosePoints = glucosePointsFromValues(clampedPredicatedGlucoseValues)
    }

    public func setAlternatePredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        alternatePredictedGlucosePoints = glucosePointsFromValues(glucoseValues)
    }
}


// MARK: - Clamping the predicted glucose values
extension PredictedGlucoseChart {
    var chartMaximumValue: LoopQuantity? {
        guard let glucosePointMaximum = glucosePoints.max(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        
        let yAxisValues = determineYAxisValues()
        
        if let maxYAxisValue = yAxisValues.last,
            maxYAxisValue.scalar > glucosePointMaximum.y.scalar
        {
            return LoopQuantity(unit: glucoseUnit, doubleValue: maxYAxisValue.scalar)
        }
        
        return LoopQuantity(unit: glucoseUnit, doubleValue: glucosePointMaximum.y.scalar)
    }
        
    var chartMinimumValue: LoopQuantity? {
        guard let glucosePointMinimum = glucosePoints.min(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        
        let yAxisValues = determineYAxisValues()
        
        if let minYAxisValue = yAxisValues.first,
            minYAxisValue.scalar < glucosePointMinimum.y.scalar
        {
            return LoopQuantity(unit: glucoseUnit, doubleValue: minYAxisValue.scalar)
        }
        
        return LoopQuantity(unit: glucoseUnit, doubleValue: glucosePointMinimum.y.scalar)
    }
    
    func clampPredictedGlucoseValues(_ glucoseValues: [GlucoseValue]) -> [GlucoseValue] {
        guard let predictedGlucoseBounds = predictedGlucoseSoftBounds else {
            return glucoseValues
        }
        
        let predictedGlucoseValueMaximum = chartMaximumValue != nil ? max(predictedGlucoseBounds.maximum, chartMaximumValue!) : predictedGlucoseBounds.maximum
        
        let predictedGlucoseValueMinimum = chartMinimumValue != nil ? min(predictedGlucoseBounds.minimum, chartMinimumValue!) : predictedGlucoseBounds.minimum
        
        return glucoseValues.map {
            if $0.quantity > predictedGlucoseValueMaximum {
                return PredictedGlucoseValue(startDate: $0.startDate, quantity: predictedGlucoseValueMaximum)
            } else if $0.quantity < predictedGlucoseValueMinimum {
                return PredictedGlucoseValue(startDate: $0.startDate, quantity: predictedGlucoseValueMinimum)
            } else {
                return $0
            }
        }
    }
    
    var chartedGlucoseValueMinimum: LoopQuantity? {
        guard let glucosePointMinimum = glucosePoints.min(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        
        return LoopQuantity(unit: glucoseUnit, doubleValue: glucosePointMinimum.y.scalar)
    }
    
    func glucoseValueBelowSoftBoundsMinimum() -> Bool {
        guard let predictedGlucoseSoftBounds = predictedGlucoseSoftBounds,
            let chartedGlucoseValueMinimum = chartedGlucoseValueMinimum else
        {
            return false
        }
            
        return chartedGlucoseValueMinimum < predictedGlucoseSoftBounds.minimum
    }
    
    public struct PredictedGlucoseBounds {
        var minimum: LoopQuantity
        var maximum: LoopQuantity
        
        public static var `default`: PredictedGlucoseBounds {
            return PredictedGlucoseBounds(minimum: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40),
                                          maximum: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 400))
        }
    }
}
