//
//  PredictedGlucoseChartTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2020-09-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
import SwiftCharts
import LoopAlgorithm
import UIKit
@testable import LoopKitUI

class PredictedGlucoseChartTests: XCTestCase {

    private let yAxisStepSizeMGDL: Double = 40
    
    func testClampingPredictedGlucoseValues40To400() {
        let glucoseValues = [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 250), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 400), startDate: Date())
        ]
        let predictedGlucoseValues =  [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 280), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 380), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 400), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 480), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 580), startDate: Date())
        ]
        let predictedGlucoseChart = PredictedGlucoseChart(predictedGlucoseBounds: .default,
                                                          yAxisStepSizeMGDLOverride: yAxisStepSizeMGDL)
        predictedGlucoseChart.setGlucoseValues(glucoseValues)
        predictedGlucoseChart.setPredictedGlucoseValues(predictedGlucoseValues)
        let predictedGlucosePoints = predictedGlucoseChart.predictedGlucosePoints
        XCTAssertEqual(predictedGlucosePoints[0].y.scalar, 40)
        XCTAssertEqual(predictedGlucosePoints[1].y.scalar, 40)
        XCTAssertEqual(predictedGlucosePoints[2].y.scalar, 280)
        XCTAssertEqual(predictedGlucosePoints[3].y.scalar, 380)
        XCTAssertEqual(predictedGlucosePoints[4].y.scalar, 400)
        XCTAssertEqual(predictedGlucosePoints[5].y.scalar, 400)
        XCTAssertEqual(predictedGlucosePoints[6].y.scalar, 400)
    }

    func testClampingPredictedGlucoseValues40To600() {
        // the max expected value is 600, but the y-axis will go to 680 due to the step size
        let glucoseValues = [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 350), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 480), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 600), startDate: Date())
        ]
        let predictedGlucoseValues =  [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 40), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 300), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 450), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 600), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 750), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 1000), startDate: Date())
        ]
        let predictedGlucoseChart = PredictedGlucoseChart(predictedGlucoseBounds: .default,
                                                          yAxisStepSizeMGDLOverride: yAxisStepSizeMGDL)
        predictedGlucoseChart.setGlucoseValues(glucoseValues)
        predictedGlucoseChart.setPredictedGlucoseValues(predictedGlucoseValues)
        let predictedGlucosePoints = predictedGlucoseChart.predictedGlucosePoints
        XCTAssertEqual(predictedGlucosePoints[0].y.scalar, 40)
        XCTAssertEqual(predictedGlucosePoints[1].y.scalar, 40)
        XCTAssertEqual(predictedGlucosePoints[2].y.scalar, 300)
        XCTAssertEqual(predictedGlucosePoints[3].y.scalar, 450)
        XCTAssertEqual(predictedGlucosePoints[4].y.scalar, 600)
        XCTAssertEqual(predictedGlucosePoints[5].y.scalar, 680)
        XCTAssertEqual(predictedGlucosePoints[6].y.scalar, 680)
    }

    func testClampingPredictedGlucoseValues0To400() {
        let glucoseValues = [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 250), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 400), startDate: Date())
        ]
        let predictedGlucoseValues =  [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: -100), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 100), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 380), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 400), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 480), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 580), startDate: Date())
        ]
        let predictedGlucoseChart = PredictedGlucoseChart(predictedGlucoseBounds: .default,
                                                          yAxisStepSizeMGDLOverride: yAxisStepSizeMGDL)
        predictedGlucoseChart.setGlucoseValues(glucoseValues)
        predictedGlucoseChart.setPredictedGlucoseValues(predictedGlucoseValues)
        let predictedGlucosePoints = predictedGlucoseChart.predictedGlucosePoints
        XCTAssertEqual(predictedGlucosePoints[0].y.scalar, 0)
        XCTAssertEqual(predictedGlucosePoints[1].y.scalar, 0)
        XCTAssertEqual(predictedGlucosePoints[2].y.scalar, 100)
        XCTAssertEqual(predictedGlucosePoints[3].y.scalar, 380)
        XCTAssertEqual(predictedGlucosePoints[4].y.scalar, 400)
        XCTAssertEqual(predictedGlucosePoints[5].y.scalar, 400)
        XCTAssertEqual(predictedGlucosePoints[6].y.scalar, 400)
    }
    
    func testClampingPredictedGlucoseValues0To600() {
        let glucoseValues = [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 120), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 350), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 480), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 600), startDate: Date())
        ]
        let predictedGlucoseValues =  [
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: -100), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 150), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 350), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 600), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 750), startDate: Date()),
            GlucoseValueTestable(quantity: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 1000), startDate: Date())
        ]
        let predictedGlucoseChart = PredictedGlucoseChart(predictedGlucoseBounds: .default,
                                                          yAxisStepSizeMGDLOverride: yAxisStepSizeMGDL)
        predictedGlucoseChart.setGlucoseValues(glucoseValues)
        predictedGlucoseChart.setPredictedGlucoseValues(predictedGlucoseValues)
        let predictedGlucosePoints = predictedGlucoseChart.predictedGlucosePoints
        XCTAssertEqual(predictedGlucosePoints[0].y.scalar, 0)
        XCTAssertEqual(predictedGlucosePoints[1].y.scalar, 0)
        XCTAssertEqual(predictedGlucosePoints[2].y.scalar, 150)
        XCTAssertEqual(predictedGlucosePoints[3].y.scalar, 350)
        XCTAssertEqual(predictedGlucosePoints[4].y.scalar, 600)
        XCTAssertEqual(predictedGlucosePoints[5].y.scalar, 600)
        XCTAssertEqual(predictedGlucosePoints[6].y.scalar, 600)
    }
}

struct GlucoseValueTestable: GlucoseValue {
    var quantity: LoopQuantity
    
    var startDate: Date
}

@MainActor
final class ChartAppearanceTests: XCTestCase {
    func testDoseScrubDisplaysActualValueInsteadOfLogCoordinate() throws {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        for dose in [-1.5, 0, 1.5] {
            let settings = ChartSettings()
            let frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            let model = ChartAxisModel(axisValues: [ChartAxisValueInt(-1), ChartAxisValueInt(1)], lineColor: .clear)
            let space = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: settings, chartFrame: frame, xModel: model, yModel: model)
            let point = ChartPoint(x: ChartAxisValueInt(0), y: ChartAxisValueDoubleLog(actualDouble: dose, unitString: "U", formatter: formatter))
            let cache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: space.xAxisLayer, yAxisLayer: space.yAxisLayer,
                axisLabelSettings: ChartLabelSettings(), chartPoints: [point],
                tintColor: .systemOrange, backgroundColor: .systemBackground)
            let chart = Chart(frame: frame, innerFrame: space.chartInnerFrame, settings: settings, layers: [cache.highlightLayer])
            cache.highlightLayer.highlightedPoint = point
            let container = try XCTUnwrap(cache.highlightLayer.view?.subviews.first)
            let labels = container.subviews.compactMap { $0 as? UILabel }
            let valueLabel = try XCTUnwrap(labels.first { $0.attributedText != nil })
            XCTAssertEqual(valueLabel.attributedText?.string, "\(formatter.string(from: NSNumber(value: dose))!)\u{00a0}U")
            withExtendedLifetime(chart) {}
        }
    }

    func testScrubOverlayMatchesSurfaceAcrossAppearanceChanges() throws {
        for background in [UIColor.systemBackground, .secondarySystemGroupedBackground, .systemPink] {
            var settings = ChartSettings()
            settings.clipInnerFrame = false
            let frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            let labelSettings = ChartLabelSettings(font: .systemFont(ofSize: 14), fontColor: .secondaryLabel)
            let values = [ChartAxisValueDouble(0, labelSettings: labelSettings), ChartAxisValueDouble(1, labelSettings: labelSettings)]
            let model = ChartAxisModel(axisValues: values, lineColor: .clear)
            let space = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: settings, chartFrame: frame, xModel: model, yModel: model)
            let point = ChartPoint(x: values[0], y: values[1])
            let cache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: space.xAxisLayer, yAxisLayer: space.yAxisLayer,
                axisLabelSettings: labelSettings, chartPoints: [point],
                tintColor: .systemBlue, backgroundColor: background)
            let chart = Chart(frame: frame, innerFrame: space.chartInnerFrame, settings: settings,
                              layers: [space.xAxisLayer, space.yAxisLayer, cache.highlightLayer])
            let window = UIWindow(frame: frame)
            let controller = UIViewController()
            window.rootViewController = controller
            controller.view.backgroundColor = background
            controller.view.addSubview(chart.view)
            window.isHidden = false
            defer { window.isHidden = true }
            cache.highlightLayer.highlightedPoint = point
            let container = try XCTUnwrap(cache.highlightLayer.view?.subviews.first)
            let overlay = try XCTUnwrap(container.subviews.first)
            XCTAssertTrue(overlay.isOpaque)
            XCTAssertTrue(container.subviews.contains { ($0 as? UILabel)?.text == "0" })
            for style in [UIUserInterfaceStyle.light, .dark, .light] {
                window.overrideUserInterfaceStyle = style
                window.layoutIfNeeded()
                let traits = overlay.traitCollection
                XCTAssertEqual(overlay.backgroundColor?.resolvedColor(with: traits), background.resolvedColor(with: traits))
            }
        }
    }

    func testPresetGaugeColorsFollowAppearanceChanges() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 200))
        let controller = UIViewController()
        window.rootViewController = controller
        let gauge = SegmentedGaugeBarView(frame: CGRect(x: 20, y: 60, width: 280, height: 24))
        gauge.startColor = .systemBlue
        gauge.endColor = .systemOrange
        gauge.borderColor = .label
        controller.view.addSubview(gauge)
        window.isHidden = false
        defer { window.isHidden = true }
        let layer = try XCTUnwrap(gauge.layer as? SegmentedGaugeBarLayer)
        for style in [UIUserInterfaceStyle.light, .dark, .light] {
            window.overrideUserInterfaceStyle = style
            window.layoutIfNeeded()
            XCTAssertEqual(layer.startColor, UIColor.systemBlue.resolvedColor(with: gauge.traitCollection).cgColor)
            XCTAssertEqual(layer.endColor, UIColor.systemOrange.resolvedColor(with: gauge.traitCollection).cgColor)
            XCTAssertEqual(layer.gaugeBorderColor, UIColor.label.resolvedColor(with: gauge.traitCollection).cgColor)
        }
    }
}
