//
//  DailyValueScheduleTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 3/27/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


final class DailyValueScheduleTests: XCTestCase {
    func testZipSingleAlignedValue() {
        let lhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.0)
        ])!
        let rhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.5)
        ])!
        let expected = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: (1.0, 1.5))
        ])!
        XCTAssert(.zip(lhs, rhs) == expected)
    }

    func testZipMultipleAlignedValues() {
        let lhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.0),
            RepeatingScheduleValue(startTime: 3600, value: 2.0),
        ])!
        let rhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.5),
            RepeatingScheduleValue(startTime: 3600, value: 3.0)
        ])!
        let expected = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: (1.0, 1.5)),
            RepeatingScheduleValue(startTime: 3600, value: (2.0, 3.0))
        ])!
        XCTAssert(.zip(lhs, rhs) == expected)
    }

    func testZipStaggeredValues() {
        let lhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.0),
            RepeatingScheduleValue(startTime: 3600, value: 2.0),
        ])!
        let rhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.5),
            RepeatingScheduleValue(startTime: 7200, value: 3.0)
        ])!
        let expected = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: (1.0, 1.5)),
            RepeatingScheduleValue(startTime: 3600, value: (2.0, 1.5)),
            RepeatingScheduleValue(startTime: 7200, value: (2.0, 3.0))
        ])!
        XCTAssert(.zip(lhs, rhs) == expected)
    }

    func testZipDifferentCounts() {
        let lhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.0),
            RepeatingScheduleValue(startTime: 3600, value: 2.0),
            RepeatingScheduleValue(startTime: 10800, value: 4.0),
        ])!
        let rhs = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.5),
            RepeatingScheduleValue(startTime: 7200, value: 3.0)
        ])!
        let expected = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: (1.0, 1.5)),
            RepeatingScheduleValue(startTime: 3600, value: (2.0, 1.5)),
            RepeatingScheduleValue(startTime: 7200, value: (2.0, 3.0)),
            RepeatingScheduleValue(startTime: 10800, value: (4.0, 3.0)),
        ])!
        XCTAssert(.zip(lhs, rhs) == expected)
    }
}
