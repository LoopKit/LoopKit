//
//  ChartAxisValuesStaticGeneratorTests.swift
//  LoopTests
//
//  Created by Nathaniel Hamming on 2020-09-29.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKitUI

class ChartAxisValuesStaticGeneratorTests: XCTestCase {

    private var maxSegmentCount: Double = 4
    private let minSegmentCount: Double = 2
    private let addPaddingSegmentIfEdge: Bool = false
    private let multiple: Double = 40

    func testGenerateYAxisValuesUsingLinearSegmentStep40To400() {
        let pointsAtLimits = [
            40,
            120,
            250,
            400,
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0], 40)
        XCTAssertEqual(yAxisValues[1], 160)
        XCTAssertEqual(yAxisValues[2], 280)
        XCTAssertEqual(yAxisValues[3], 400)
        
        let pointsNearLimits = [
            41,
            42,
            43,
            397,
            398,
            399,
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0], 40)
        XCTAssertEqual(yAxisValues[1], 160)
        XCTAssertEqual(yAxisValues[2], 280)
        XCTAssertEqual(yAxisValues[3], 400)
    }
    
    func testGenerateYAxisValuesUsingLinearSegmentStep40To600() {
        // the max expected value is 600, but the y-axis will go to 680 due to the step size
        let pointsAtLimits = [
            40,
            120,
            250,
            600,
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0], 40)
        XCTAssertEqual(yAxisValues[1], 200)
        XCTAssertEqual(yAxisValues[2], 360)
        XCTAssertEqual(yAxisValues[3], 520)
        XCTAssertEqual(yAxisValues[4], 680)
        
        let pointsNearLimits = [
            41,
            42,
            43,
            597,
            598,
            599,
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0], 40)
        XCTAssertEqual(yAxisValues[1], 200)
        XCTAssertEqual(yAxisValues[2], 360)
        XCTAssertEqual(yAxisValues[3], 520)
        XCTAssertEqual(yAxisValues[4], 680)
    }

    func testGenerateYAxisValuesUsingLinearSegmentStep0To400() {
        // when starting at 0, the max segment size is set to 5
        maxSegmentCount = 5

        let pointsAtLimits = [
                0,
                120,
                250,
                400,
            ]
            var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
            XCTAssertEqual(yAxisValues[0], 0)
            XCTAssertEqual(yAxisValues[1], 80)
            XCTAssertEqual(yAxisValues[2], 160)
            XCTAssertEqual(yAxisValues[3], 240)
            XCTAssertEqual(yAxisValues[4], 320)
            XCTAssertEqual(yAxisValues[5], 400)
            
            let pointsNearLimits = [
                1,
                2,
                3,
                397,
                398,
                399,
            ]
            yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
            XCTAssertEqual(yAxisValues[0], 0)
            XCTAssertEqual(yAxisValues[1], 80)
            XCTAssertEqual(yAxisValues[2], 160)
            XCTAssertEqual(yAxisValues[3], 240)
            XCTAssertEqual(yAxisValues[4], 320)
            XCTAssertEqual(yAxisValues[5], 400)
    }
    
    func testGenerateYAxisValuesUsingLinearSegmentStep0To680() {
        // when starting at 0, the max segment size is set to 5
        maxSegmentCount = 5
        
        let pointsAtLimits = [
            0,
            120,
            250,
            600,
        ]
        var yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsAtLimits)
        XCTAssertEqual(yAxisValues[0], 0)
        XCTAssertEqual(yAxisValues[1], 120)
        XCTAssertEqual(yAxisValues[2], 240)
        XCTAssertEqual(yAxisValues[3], 360)
        XCTAssertEqual(yAxisValues[4], 480)
        XCTAssertEqual(yAxisValues[5], 600)
        
        let pointsNearLimits = [
            1,
            2,
            3,
            597,
            598,
            599,
        ]
        yAxisValues = generateYAxisValuesUsingLinearSegmentStep(chartPoints: pointsNearLimits)
        XCTAssertEqual(yAxisValues[0], 0)
        XCTAssertEqual(yAxisValues[1], 120)
        XCTAssertEqual(yAxisValues[2], 240)
        XCTAssertEqual(yAxisValues[3], 360)
        XCTAssertEqual(yAxisValues[4], 480)
        XCTAssertEqual(yAxisValues[5], 600)
    }
}

extension ChartAxisValuesStaticGeneratorTests {
    func generateYAxisValuesUsingLinearSegmentStep(chartPoints: [Double]) -> [Double] {
        return ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(chartValues: chartPoints,
                                                                                        minSegmentCount: minSegmentCount,
                                                                                        maxSegmentCount: maxSegmentCount,
                                                                                        multiple: multiple,
                                                                                        addPaddingSegmentIfEdge: addPaddingSegmentIfEdge)
    }
}
