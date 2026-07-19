//
//  IOBChart.swift
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


public class IOBChart: ChartProviding {

    static let chartUnit = LoopUnit.internationalUnit

    public init() {
    }

    /// The chart points for IOB
    public private(set) var iobPoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = iobPoints.last?.date {
                endDate = lastDate
            }
        }
    }

    /// The minimum range to display for insulin values.
    private let iobDisplayRangeValues: [Double] = [0, 1]

    public private(set) var endDate: Date?

    private let gestureBridge = ChartGestureBridge()
}

public extension IOBChart {
    func didReceiveMemoryWarning() {
        iobPoints = []
    }

    func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(
            chartValues: iobPoints.map { $0.y.scalar } + iobDisplayRangeValues,
            minSegmentCount: 2,
            maxSegmentCount: 3,
            multiple: 0.5,
            addPaddingSegmentIfEdge: false
        )

        let insulinColor = Color(context.colors.insulinTint)
        let areaColor = Color(context.colors.insulinTint.withAlphaComponent(0.5))
        let points = iobPoints.datedPoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            highlight = ChartHighlightSpec(points: iobPoints, tintColor: context.colors.insulinTint)
        } else {
            highlight = nil
        }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            highlight: highlight,
            highlightModel: gestureBridge.model
        ) {
            // The IOB area
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                AreaMark(
                    x: .value("Date", point.date!),
                    yStart: .value("Zero", 0),
                    yEnd: .value("IOB", point.y.scalar)
                )
                .foregroundStyle(areaColor)
            }

            // The IOB line
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Date", point.date!),
                    y: .value("IOB", point.y.scalar),
                    series: .value("Series", "IOB")
                )
            }
            .lineStyle(ChartLineStyle.valueLine())
            .foregroundStyle(insulinColor)

            // 0-line
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 0.5))
                .foregroundStyle(insulinColor)
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
}

public extension IOBChart {
    func setIOBValues(_ iobValues: [InsulinValue]) {
        let doseFormatter = NumberFormatter.dose

        iobPoints = iobValues.map {
            return ChartPoint(
                date: $0.startDate,
                y: ChartValue(
                    scalar: $0.value,
                    unitString: Self.chartUnit.shortLocalizedUnitString(),
                    formatter: doseFormatter
                )
            )
        }
    }
}
