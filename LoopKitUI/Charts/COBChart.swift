//
//  COBChart.swift
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

public class COBChart: ChartProviding {
    public init() {
    }

    /// The chart points for COB
    public private(set) var cobPoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = cobPoints.last?.date {
                endDate = lastDate
            }
        }
    }

    /// The minimum range to display for COB values.
    private let cobDisplayRangeValues: [Double] = [0, 10]

    public private(set) var endDate: Date?

    private let gestureBridge = ChartGestureBridge()
}

public extension COBChart {
    func didReceiveMemoryWarning() {
        cobPoints = []
    }

    func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(
            chartValues: cobPoints.map { $0.y.scalar } + cobDisplayRangeValues,
            minSegmentCount: 2,
            maxSegmentCount: 3,
            multiple: 10,
            addPaddingSegmentIfEdge: false
        )

        let carbColor = Color(context.colors.carbTint)
        let areaColor = Color(context.colors.carbTint.withAlphaComponent(0.5))
        let points = cobPoints.datedPoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            highlight = ChartHighlightSpec(points: cobPoints, tintColor: context.colors.carbTint)
        } else {
            highlight = nil
        }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            highlight: highlight,
            highlightModel: gestureBridge.model
        ) {
            // The COB area
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date!),
                    yStart: .value("Zero", 0),
                    yEnd: .value("COB", point.y.scalar)
                )
                .foregroundStyle(areaColor)
            }

            // The COB line
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date!),
                    y: .value("COB", point.y.scalar),
                    series: .value("Series", "COB")
                )
            }
            .lineStyle(ChartLineStyle.valueLine())
            .foregroundStyle(carbColor)
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
}

public extension COBChart {
    func setCOBValues(_ cobValues: [CarbValue]) {
        let integerFormatter = NumberFormatter.integer

        let unit = LoopUnit.gram
        let unitString = unit.unitString

        cobPoints = cobValues.map {
            ChartPoint(
                date: $0.startDate,
                y: ChartValue(
                    scalar: $0.quantity.doubleValue(for: unit),
                    unitString: unitString,
                    formatter: integerFormatter
                )
            )
        }
    }
}
