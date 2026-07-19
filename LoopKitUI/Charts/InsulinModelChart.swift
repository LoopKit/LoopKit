//
//  InsulinModelChart.swift
//  LoopKitUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Charts
import Foundation
import LoopKit
import SwiftUI
import UIKit
import LoopAlgorithm

public class InsulinModelChart: GlucoseChart, ChartProviding {
    /// The chart points for the selected model
    public private(set) var selectedInsulinModelChartPoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = selectedInsulinModelChartPoints.last?.date {
                updateEndDate(lastDate)
            }
        }
    }

    public private(set) var unselectedInsulinModelChartPoints: [[ChartPoint]] = [] {
        didSet {
            for points in unselectedInsulinModelChartPoints {
                if let lastDate = points.last?.date {
                    updateEndDate(lastDate)
                }
            }
        }
    }

    public private(set) var endDate: Date?

    private let gestureBridge = ChartGestureBridge()

    private func updateEndDate(_ date: Date) {
        if endDate == nil || date > endDate! {
            self.endDate = date
        }
    }
}

extension InsulinModelChart {
    public func didReceiveMemoryWarning() {

    }

    public func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        guard #available(iOS 16.0, *) else {
            return UIView(frame: frame)
        }

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(
            chartValues: glucoseDisplayRangePoints.map { $0.y.scalar },
            minSegmentCount: 2,
            maxSegmentCount: 5,
            multiple: glucoseUnit.chartableIncrement / 2,
            addPaddingSegmentIfEdge: false
        ).map { round($0) }

        let glucoseColor = Color(context.colors.glucoseTint)
        let unselectedColor = Color(UIColor.secondaryLabel)
        let selectedPoints = selectedInsulinModelChartPoints.datedPoints
        let unselectedPointSets = unselectedInsulinModelChartPoints.map { $0.datedPoints }

        let chartView = LoopChartView(
            generationContext: context,
            yAxisValues: yAxisValues,
            highlightModel: gestureBridge.model
        ) {
            // Unselected lines
            ForEach(Array(unselectedPointSets.enumerated()), id: \.offset) { setIndex, points in
                if points.count > 1 {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date!),
                            y: .value("Glucose", point.y.scalar),
                            series: .value("Series", "Unselected-\(setIndex)")
                        )
                    }
                    .lineStyle(ChartLineStyle.predictionLine(width: 1))
                    .foregroundStyle(unselectedColor)
                }
            }

            // Selected line
            if selectedPoints.count > 1 {
                ForEach(Array(selectedPoints.enumerated()), id: \.offset) { _, point in
                    LineMark(
                        x: .value("Date", point.date!),
                        y: .value("Glucose", point.y.scalar),
                        series: .value("Series", "Selected")
                    )
                }
                .lineStyle(ChartLineStyle.predictionLine(width: 2))
                .foregroundStyle(glucoseColor)
            }
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }
}

extension InsulinModelChart {
    public func setSelectedInsulinModelValues(_ values: [GlucoseValue]) {
        self.selectedInsulinModelChartPoints = glucosePointsFromValues(values)
    }

    public func setUnselectedInsulinModelValues(_ values: [[GlucoseValue]]) {
        self.unselectedInsulinModelChartPoints = values.map(glucosePointsFromValues)
    }
}
