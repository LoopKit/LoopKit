//
//  ChartAxisValuesStaticGeneratorTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2020-09-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import UIKit
import LoopKit
import SwiftCharts
@testable import LoopKitUI

class ChartAxisValuesStaticGeneratorTests: XCTestCase {

    private var maxSegmentCount: Double = 4
    private let minSegmentCount: Double = 2
    private let axisValueGenerator: ChartAxisValueStaticGenerator = { ChartAxisValueDouble($0) }
    private let addPaddingSegmentIfEdge: Bool = false
    private let multiple: Double = 40

    func testGenerateYAxisValuesUsingLinearSegmentStep40To400() {
        let pointsAtLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 40)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 120)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 250)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 400)),
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 40)
        XCTAssertEqual(yAxisValues[1].scalar, 160)
        XCTAssertEqual(yAxisValues[2].scalar, 280)
        XCTAssertEqual(yAxisValues[3].scalar, 400)
        
        let pointsNearLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 41)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 42)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 43)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 397)),
            ChartPoint(x: ChartAxisValue(scalar: 5), y:  ChartAxisValue(scalar: 398)),
            ChartPoint(x: ChartAxisValue(scalar: 6), y:  ChartAxisValue(scalar: 399)),
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 40)
        XCTAssertEqual(yAxisValues[1].scalar, 160)
        XCTAssertEqual(yAxisValues[2].scalar, 280)
        XCTAssertEqual(yAxisValues[3].scalar, 400)
    }
    
    func testGenerateYAxisValuesUsingLinearSegmentStep40To600() {
        // the max expected value is 600, but the y-axis will go to 680 due to the step size
        let pointsAtLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 40)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 120)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 250)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 600)),
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 40)
        XCTAssertEqual(yAxisValues[1].scalar, 200)
        XCTAssertEqual(yAxisValues[2].scalar, 360)
        XCTAssertEqual(yAxisValues[3].scalar, 520)
        XCTAssertEqual(yAxisValues[4].scalar, 680)
        
        let pointsNearLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 41)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 42)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 43)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 597)),
            ChartPoint(x: ChartAxisValue(scalar: 5), y:  ChartAxisValue(scalar: 598)),
            ChartPoint(x: ChartAxisValue(scalar: 6), y:  ChartAxisValue(scalar: 599)),
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 40)
        XCTAssertEqual(yAxisValues[1].scalar, 200)
        XCTAssertEqual(yAxisValues[2].scalar, 360)
        XCTAssertEqual(yAxisValues[3].scalar, 520)
        XCTAssertEqual(yAxisValues[4].scalar, 680)
    }

    func testGenerateYAxisValuesUsingLinearSegmentStep0To400() {
        // when starting at 0, the max segment size is set to 5
        maxSegmentCount = 5

        let pointsAtLimits = [
                ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 0)),
                ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 120)),
                ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 250)),
                ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 400)),
            ]
            var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
            XCTAssertEqual(yAxisValues[0].scalar, 0)
            XCTAssertEqual(yAxisValues[1].scalar, 80)
            XCTAssertEqual(yAxisValues[2].scalar, 160)
            XCTAssertEqual(yAxisValues[3].scalar, 240)
            XCTAssertEqual(yAxisValues[4].scalar, 320)
            XCTAssertEqual(yAxisValues[5].scalar, 400)
            
            let pointsNearLimits = [
                ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 1)),
                ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 2)),
                ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 3)),
                ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 397)),
                ChartPoint(x: ChartAxisValue(scalar: 5), y:  ChartAxisValue(scalar: 398)),
                ChartPoint(x: ChartAxisValue(scalar: 6), y:  ChartAxisValue(scalar: 399)),
            ]
            yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
            XCTAssertEqual(yAxisValues[0].scalar, 0)
            XCTAssertEqual(yAxisValues[1].scalar, 80)
            XCTAssertEqual(yAxisValues[2].scalar, 160)
            XCTAssertEqual(yAxisValues[3].scalar, 240)
            XCTAssertEqual(yAxisValues[4].scalar, 320)
            XCTAssertEqual(yAxisValues[5].scalar, 400)
    }
    
    func testGenerateYAxisValuesUsingLinearSegmentStep0To680() {
        // when starting at 0, the max segment size is set to 5
        maxSegmentCount = 5
        
        let pointsAtLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 0)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 120)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 250)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 600)),
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 0)
        XCTAssertEqual(yAxisValues[1].scalar, 120)
        XCTAssertEqual(yAxisValues[2].scalar, 240)
        XCTAssertEqual(yAxisValues[3].scalar, 360)
        XCTAssertEqual(yAxisValues[4].scalar, 480)
        XCTAssertEqual(yAxisValues[5].scalar, 600)
        
        let pointsNearLimits = [
            ChartPoint(x: ChartAxisValue(scalar: 1), y:  ChartAxisValue(scalar: 1)),
            ChartPoint(x: ChartAxisValue(scalar: 2), y:  ChartAxisValue(scalar: 2)),
            ChartPoint(x: ChartAxisValue(scalar: 3), y:  ChartAxisValue(scalar: 3)),
            ChartPoint(x: ChartAxisValue(scalar: 4), y:  ChartAxisValue(scalar: 597)),
            ChartPoint(x: ChartAxisValue(scalar: 5), y:  ChartAxisValue(scalar: 598)),
            ChartPoint(x: ChartAxisValue(scalar: 6), y:  ChartAxisValue(scalar: 599)),
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0].scalar, 0)
        XCTAssertEqual(yAxisValues[1].scalar, 120)
        XCTAssertEqual(yAxisValues[2].scalar, 240)
        XCTAssertEqual(yAxisValues[3].scalar, 360)
        XCTAssertEqual(yAxisValues[4].scalar, 480)
        XCTAssertEqual(yAxisValues[5].scalar, 600)
    }
}

extension ChartAxisValuesStaticGeneratorTests {
    func generateYAxisValuesUsingLinearSegmentStep(chartPoints: [ChartPoint]) -> [ChartAxisValue] {
        return ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(chartPoints: chartPoints,
                                                                                        minSegmentCount: minSegmentCount,
                                                                                        maxSegmentCount: maxSegmentCount,
                                                                                        multiple: multiple,
                                                                                        axisValueGenerator: axisValueGenerator,
                                                                                        addPaddingSegmentIfEdge: addPaddingSegmentIfEdge)
    }
}

final class ChartsManagerLabelWidthTests: XCTestCase {
    private let colors = ChartColorPalette(axisLine: .clear, axisLabel: .gray, grid: .gray, presetTint: .gray, glucoseTint: .gray, insulinTint: .gray, carbTint: .gray)

    func testCarbEffectChartReservesSpaceForSignedFractionalLabels() {
        let font = UIFont.systemFont(ofSize: 14)
        let manager = ChartsManager(colors: colors, settings: ChartSettings(), charts: [CarbEffectChart()], traitCollection: UITraitCollection())
        let labelWidth = manager.fixedHorizontalMargin - ChartSettings().labelsToAxisSpacingY
        for locale in ["en_US", "de_DE"] {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: locale)
            formatter.maximumFractionDigits = 2
            for value in [-0.08, -12.34] {
                let text = formatter.string(from: NSNumber(value: value))!
                XCTAssertLessThanOrEqual((text as NSString).size(withAttributes: [.font: font]).width, labelWidth, "\(locale): \(text)")
            }
        }
        XCTAssertEqual(labelWidth, 50)
    }

    func testSharedManagerUsesOneMarginAndAlignedChartFrames() {
        let glucose = GlucoseCarbChart()
        glucose.glucoseDisplayRange = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 60)...LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
        var settings = ChartSettings()
        settings.axisTitleLabelsToLabelsSpacing = 0
        let manager = ChartsManager(colors: colors, settings: settings, charts: [glucose, IOBChart(), LegacyDoseChart(), CarbEffectChart()], traitCollection: UITraitCollection())
        manager.prerender()
        let frame = CGRect(x: 0, y: 0, width: 402, height: 150)
        let charts = (0..<4).compactMap { manager.chart(atIndex: $0, frame: frame) }
        XCTAssertEqual(charts.count, 4)
        XCTAssertEqual(manager.fixedHorizontalMargin, 55)
        for chart in charts {
            XCTAssertEqual(chart.innerFrame.minX, 56)
            XCTAssertEqual(chart.innerFrame.width, charts[0].innerFrame.width)
        }
    }

    func testCarbEffectMarginIsUsedForAvailableTimeRange() {
        var settings = ChartSettings()
        settings.trailing = 8
        let carbManager = ChartsManager(colors: colors, settings: settings, charts: [CarbEffectChart()], traitCollection: UITraitCollection())
        let otherManager = ChartsManager(colors: colors, settings: settings, charts: [IOBChart()], traitCollection: UITraitCollection())
        func hours(_ width: CGFloat, _ manager: ChartsManager) -> Int {
            Int(floor((width - manager.fixedHorizontalMargin) / 75))
        }
        XCTAssertEqual(carbManager.fixedHorizontalMargin, 63)
        XCTAssertEqual(hours(402, carbManager), 4)
        XCTAssertEqual(hours(874, carbManager), 10)
        XCTAssertEqual(hours(874, otherManager), 11)
    }

    func testManagerWithoutCarbEffectChartKeepsExistingMargin() {
        let manager = ChartsManager(colors: colors, settings: ChartSettings(), charts: [IOBChart()], traitCollection: UITraitCollection())
        XCTAssertEqual(manager.fixedHorizontalMargin, 35)
    }
}
