//
//  PredictedGlucoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Charts
import Foundation
import LoopKit
import SwiftUI
import UIKit
import LoopAlgorithm

public class PredictedGlucoseChart: GlucoseChart, ChartProviding {

    public private(set) var glucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = glucosePoints.last?.date {
                updateEndDate(lastDate)
            }
        }
    }

    /// The chart points for predicted glucose
    public private(set) var predictedGlucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = predictedGlucosePoints.last?.date {
                updateEndDate(lastDate)
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

    private let gestureBridge = ChartGestureBridge()

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
    }

    public func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        if targetGlucosePoints.isEmpty, let schedule = targetGlucoseSchedule {

            // TODO: This only considers one override: pre-meal or an active override. TargetChartBar.barsForGlucoseRangeSchedule needs to accept list of overridden ranges.
            let potentialOverride = (preMealOverride?.isActive() ?? false) ? preMealOverride : (scheduleOverride?.isActive() ?? false) ? scheduleOverride : nil
            targetGlucosePoints = TargetChartBar.barsForGlucoseRangeSchedule(schedule, unit: glucoseUnit, chartStartDate: context.xAxisModel.startDate, chartEndDate: context.xAxisModel.endDate, considering: potentialOverride)
        }

        let yAxisValues = determineYAxisValues()

        // The glucose targets
        let targetFill = context.colors.glucoseTint.withAlphaComponent(0.2)
        let overrideFill = context.colors.presetTint.withAlphaComponent(0.6)

        let glucoseColor = Color(context.colors.glucoseTint)
        let glucosePoints = self.glucosePoints.datedPoints
        let predictedGlucosePoints = self.predictedGlucosePoints.datedPoints
        let alternatePredictedGlucosePoints = self.alternatePredictedGlucosePoints?.datedPoints ?? []
        let predictionLineColor = alternatePredictedGlucosePoints.count > 1 ? Color(UIColor.secondaryLabel) : glucoseColor
        let targetBars = targetGlucosePoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            highlight = ChartHighlightSpec(
                points: self.glucosePoints + (self.alternatePredictedGlucosePoints ?? self.predictedGlucosePoints),
                tintColor: context.colors.glucoseTint
            )
        } else {
            highlight = nil
        }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            highlight: highlight,
            highlightModel: gestureBridge.model
        ) {
            // The glucose targets
            ForEach(Array(targetBars.enumerated()), id: \.offset) { _, bar in
                RectangleMark(
                    xStart: .value("Start", bar.startDate),
                    xEnd: .value("End", bar.endDate),
                    yStart: .value("Min", bar.minValue),
                    yEnd: .value("Max", bar.maxValue)
                )
                .foregroundStyle(Color(bar.isOverride ? overrideFill : targetFill))
            }

            // The prediction line
            if predictedGlucosePoints.count > 1 {
                ForEach(Array(predictedGlucosePoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date!),
                        y: .value("Glucose", point.y.scalar),
                        series: .value("Series", "Prediction")
                    )
                }
                .lineStyle(ChartLineStyle.predictionLine(width: 1))
                .foregroundStyle(predictionLineColor)
            }

            // The alternate prediction line
            if alternatePredictedGlucosePoints.count > 1 {
                ForEach(Array(alternatePredictedGlucosePoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date!),
                        y: .value("Glucose", point.y.scalar),
                        series: .value("Series", "AlternatePrediction")
                    )
                }
                .lineStyle(ChartLineStyle.predictionLine(width: 2))
                .foregroundStyle(glucoseColor)
            }

            // The glucose values
            ForEach(Array(glucosePoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Glucose", point.y.scalar)
                )
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(glucoseColor)
            }
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }

    private func determineYAxisValues() -> [Double] {
        let scalars = [
            glucosePoints, predictedGlucosePoints,
            glucoseDisplayRangePoints
        ].flatMap { $0 }.map { $0.y.scalar }

        let barScalars = targetGlucosePoints.flatMap { [$0.minValue, $0.maxValue] }

        let allScalars = scalars + barScalars

        guard !allScalars.isEmpty else {
            return []
        }

        return ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(chartValues: allScalars,
            minSegmentCount: 2,
            maxSegmentCount: maxYAxisSegmentCount,
            multiple: glucoseUnit == .milligramsPerDeciliter ? (yAxisStepSizeMGDLOverride ?? 25) : 1,
            addPaddingSegmentIfEdge: false
        )
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
            maxYAxisValue > glucosePointMaximum.y.scalar
        {
            return LoopQuantity(unit: glucoseUnit, doubleValue: maxYAxisValue)
        }
        
        return LoopQuantity(unit: glucoseUnit, doubleValue: glucosePointMaximum.y.scalar)
    }
        
    var chartMinimumValue: LoopQuantity? {
        guard let glucosePointMinimum = glucosePoints.min(by: { point1, point2 in point1.y.scalar < point2.y.scalar }) else {
            return nil
        }
        
        let yAxisValues = determineYAxisValues()
        
        if let minYAxisValue = yAxisValues.first,
            minYAxisValue < glucosePointMinimum.y.scalar
        {
            return LoopQuantity(unit: glucoseUnit, doubleValue: minYAxisValue)
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

extension Array where Element == ChartPoint {
    /// The points that have a date and can therefore be plotted on the time axis
    var datedPoints: [ChartPoint] {
        return filter { $0.date != nil }
    }
}
