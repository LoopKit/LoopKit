//
//  CarbEffectChart.swift
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

public class CarbEffectChart: GlucoseChart, ChartProviding {
    /// The chart points for expected carb effect velocity
    public private(set) var carbEffectPoints: [ChartPoint] = [] {
        didSet {
            // don't extend the end date for carb effects
        }
    }

    /// The chart points for observed insulin counteraction effect velocity
    public private(set) var insulinCounteractionEffectPoints: [ChartPoint] = [] {
        didSet {
            // Extend 1 hour past the seen effect to ensure some future prediction is displayed
            if let lastDate = insulinCounteractionEffectPoints.last?.date {
                endDate = lastDate.addingTimeInterval(.hours(1))
            }
        }
    }

    /// The chart points used for selection in the carb effect chart
    public private(set) var allCarbEffectPoints: [ChartPoint] = []

    public private(set) var endDate: Date?

    private lazy var decimalFormatter = NumberFormatter.dose

    private let gestureBridge = ChartGestureBridge()
}

extension CarbEffectChart {
    public func didReceiveMemoryWarning() {
        carbEffectPoints = []
        insulinCounteractionEffectPoints = []
        allCarbEffectPoints = []
    }

    public func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        /// The minimum range to display for carb effect values.
        let carbEffectDisplayRangeValues: [Double] = [0, glucoseUnit.chartableIncrement]

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(
            chartValues: (carbEffectPoints + allCarbEffectPoints).map { $0.y.scalar } + carbEffectDisplayRangeValues,
            minSegmentCount: 2,
            maxSegmentCount: 4,
            multiple: glucoseUnit.chartableIncrement / 2,
            addPaddingSegmentIfEdge: false
        )

        let carbFillColor = context.colors.carbTint.withAlphaComponent(0.5)
        let expectedFillColor = Color(UIColor.secondaryLabel.withAlphaComponent(0.5))
        let observedFillColor = Color(carbFillColor)
        let expectedPoints = carbEffectPoints.datedPoints
        let observedPoints = insulinCounteractionEffectPoints.datedPoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            highlight = ChartHighlightSpec(points: allCarbEffectPoints, tintColor: context.colors.carbTint)
        } else {
            highlight = nil
        }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            highlight: highlight,
            highlightModel: gestureBridge.model
        ) {
            // The expected carb effect
            ForEach(Array(expectedPoints.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date!),
                    yStart: .value("Zero", 0),
                    yEnd: .value("Effect", point.y.scalar),
                    series: .value("Series", "Expected")
                )
                .foregroundStyle(expectedFillColor)
            }

            // The observed insulin counteraction effect
            ForEach(Array(observedPoints.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date!),
                    yStart: .value("Zero", 0),
                    yEnd: .value("Effect", point.y.scalar),
                    series: .value("Series", "Observed")
                )
                .foregroundStyle(observedFillColor)
            }

            // 0-line
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color(carbFillColor))
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
}

extension CarbEffectChart {
    /// Convert an array of GlucoseEffects (as glucose values) into glucose effect velocity (glucose/min) for charting
    ///
    /// - Parameter effects: A timeline of glucose values representing glucose change
    public func setCarbEffects(_ effects: [GlucoseEffect]) {
        let unit = glucoseUnit.unitDivided(by: .minute)
        let unitString = unit.unitString

        var lastDate = effects.first?.endDate
        var lastValue = effects.first?.quantity.doubleValue(for: glucoseUnit)
        let minuteInterval = 5.0

        var carbEffectPoints = [ChartPoint]()

        for effect in effects.dropFirst() {
            let value = effect.quantity.doubleValue(for: glucoseUnit)
            let valuePerMinute = (value - lastValue!) / minuteInterval
            lastValue = value

            let startX = lastDate!
            let endX = effect.endDate
            lastDate = effect.endDate

            let valueY = ChartValue(scalar: valuePerMinute, unitString: unitString, formatter: decimalFormatter)
            let zero = ChartValue(scalar: 0, label: "")

            carbEffectPoints += [
                ChartPoint(date: startX, y: zero),
                ChartPoint(date: startX, y: valueY),
                ChartPoint(date: endX, y: valueY),
                ChartPoint(date: endX, y: zero)
            ]
        }

        self.carbEffectPoints = carbEffectPoints
    }

    /// Charts glucose effect velocity
    ///
    /// - Parameter effects: A timeline of glucose velocity values
    public func setInsulinCounteractionEffects(_ effects: [GlucoseEffectVelocity]) {
        let unit = glucoseUnit.unitDivided(by: .minute)
        let unitString = String(format: NSLocalizedString("%1$@/min", comment: "Format string describing glucose units per minute (1: glucose unit string)"), glucoseUnit.shortLocalizedUnitString())

        var insulinCounteractionEffectPoints: [ChartPoint] = []
        var allCarbEffectPoints: [ChartPoint] = []

        for effect in effects {
            let startX = effect.startDate
            let endX = effect.endDate
            let value = ChartValue(scalar: effect.quantity.doubleValue(for: unit), unitString: unitString, formatter: decimalFormatter)
            let zero = ChartValue(scalar: 0, label: "")

            guard value.scalar != 0 else {
                continue
            }

            let valuePoint = ChartPoint(date: endX, y: value)

            insulinCounteractionEffectPoints += [
                ChartPoint(date: startX, y: zero),
                ChartPoint(date: startX, y: value),
                valuePoint,
                ChartPoint(date: endX, y: zero)
            ]

            allCarbEffectPoints.append(valuePoint)
        }

        self.insulinCounteractionEffectPoints = insulinCounteractionEffectPoints
        self.allCarbEffectPoints = allCarbEffectPoints
    }
}
