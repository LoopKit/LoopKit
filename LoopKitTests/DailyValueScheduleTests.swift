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

    func testBetweenSpanningManyDays() {
        let schedule = DailyValueSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 1.0),
            RepeatingScheduleValue(startTime: 43200, value: 2.0),
        ], timeZone: TimeZone(secondsFromGMT: 0))!
        let start = Date(timeIntervalSinceReferenceDate: 3600)
        let days = 6 * 365
        let end = start.addingTimeInterval(TimeInterval(days * 86400))

        var values: [AbsoluteScheduleValue<Double>] = []
        let done = expectation(description: "between")
        // Same stack size as a Swift concurrency cooperative thread
        let thread = Thread {
            values = schedule.between(start: start, end: end)
            done.fulfill()
        }
        thread.stackSize = 512 * 1024
        thread.start()
        wait(for: [done], timeout: 30)

        XCTAssertEqual(values.count, days * 2 + 1)
        XCTAssertEqual(values.first?.startDate, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(values.first?.endDate, Date(timeIntervalSinceReferenceDate: 43200))
        XCTAssertEqual(values.last?.startDate, end.addingTimeInterval(-3600))
        XCTAssertEqual(values.last?.endDate, end.addingTimeInterval(43200 - 3600))
        for (previous, next) in zip(values, values.dropFirst()) {
            XCTAssertEqual(previous.endDate, next.startDate)
        }
    }
}
