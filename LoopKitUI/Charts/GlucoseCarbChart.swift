//
//  GlucoseCarbChart.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/26/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Charts
import Foundation
import LoopKit
import SwiftUI
import UIKit
import LoopAlgorithm

public class GlucoseCarbChart: GlucoseChart, ChartProviding {

    public private(set) var glucosePoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = glucosePoints.last?.date {
                updateEndDate(lastDate)
            }
        }
    }
    
    public var carbEntries: [StoredCarbEntry] = []
    
    /// Image to display for each carb entry on x-axis of graph
    public var carbEntryImage: UIImage?
    /// Image to display for when carb entry is a favorite food
    public var carbEntryFavoriteFoodImage: UIImage?

    private let gestureBridge = ChartGestureBridge()

    public private(set) var endDate: Date?
        
    private let yAxisStepSizeMGDLOverride: Double?
        
    private var maxYAxisSegmentCount: Double { 4 }
    
    private let carbEntryImageSize = CGSize(width: 16, height: 16)

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
    }

    public func generate(withFrame frame: CGRect, context: ChartGenerationContext) -> UIView
    {
        guard #available(iOS 16.0, *) else {
            return UIView(frame: frame)
        }

        let yAxisValues = determineYAxisValues()

        let carbPoints = generateCarbChartPoints(carbEntries, fixedYValue: yAxisValues.min(), overrideColor: context.colors.carbTint)

        let glucoseColor = Color(context.colors.glucoseTint)
        let carbColor = Color(context.colors.carbTint)
        let glucosePoints = self.glucosePoints.datedPoints
        let datedCarbPoints = carbPoints.datedPoints

        let highlight: ChartHighlightSpec?
        if context.gestureRecognizer != nil {
            let highlightPoints = (self.glucosePoints + carbPoints).sorted { $0.startDate < $1.startDate }
            highlight = ChartHighlightSpec(
                points: highlightPoints,
                tintColor: context.colors.glucoseTint,
                highlightPointOffsetY: 8
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
            // The glucose values
            ForEach(Array(glucosePoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Glucose", point.y.scalar)
                )
                .symbolSize(CGSize(width: 4, height: 4))
                .foregroundStyle(glucoseColor)
            }

            // The carb entries
            ForEach(Array(datedCarbPoints.enumerated()), id: \.offset) { _, point in
                PointMark(
                    x: .value("Date", point.date!),
                    y: .value("Carbs", point.y.scalar)
                )
                .symbol {
                    self.carbEntrySymbol(isFavoriteFood: point.isFavoriteFood == true, tintColor: carbColor)
                }
            }
        }

        let host = ChartHosting.view(frame: frame, rootView: chartView)
        gestureBridge.attach(to: context.gestureRecognizer, hostView: host)
        return host
    }

    private func carbEntrySymbol(isFavoriteFood: Bool, tintColor: Color) -> some View {
        let image: UIImage
        if isFavoriteFood, let carbEntryFavoriteFoodImage = carbEntryFavoriteFoodImage {
            image = carbEntryFavoriteFoodImage
        } else if let carbEntryImage = carbEntryImage {
            image = carbEntryImage
        } else {
            image = UIImage(systemName: "fork.knife.circle.fill") ?? UIImage()
        }

        return Image(uiImage: image.withRenderingMode(.alwaysTemplate))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: carbEntryImageSize.width, height: carbEntryImageSize.height)
            .foregroundColor(tintColor)
    }

    private func determineYAxisValues() -> [Double] {
        let scalars = [
            glucosePoints,
            glucoseDisplayRangePoints
        ].flatMap { $0 }.map { $0.y.scalar }

        guard !scalars.isEmpty else {
            return []
        }

        return ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(chartValues: scalars,
            minSegmentCount: 2,
            maxSegmentCount: maxYAxisSegmentCount,
            multiple: glucoseUnit == .milligramsPerDeciliter ? (yAxisStepSizeMGDLOverride ?? 25) : 1,
            addPaddingSegmentIfEdge: false
        )
    }
    
    private func generateCarbChartPoints(_ carbEntries: [StoredCarbEntry], fixedYValue: Double?, overrideColor: UIColor) -> [ChartPoint] {
        guard let fixedYValue = fixedYValue else { return [] }

        let carbFormatter = QuantityFormatter(for: .gram)
        carbFormatter.unitStyle = .short
        let unitString = carbFormatter.localizedUnitStringWithPlurality()
        
        return carbEntries.map { entry in
            ChartPoint.carbEntry(
                date: entry.startDate,
                carbQuantity: entry.amount,
                fixedY: fixedYValue,
                unitString: unitString,
                formatter: carbFormatter.numberFormatter,
                isFavoriteFood: entry.favoriteFoodID != nil,
                overrideColor: overrideColor,
                overrideHighlightPointSize: 22
            )
        }
    }
}

extension GlucoseCarbChart {
    public func setGlucoseValues(_ glucoseValues: [GlucoseValue]) {
        glucosePoints = glucosePointsFromValues(glucoseValues)
    }
}
