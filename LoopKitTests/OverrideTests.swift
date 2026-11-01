//
//  OverrideTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-09.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest

@testable import LoopKit

class OverrideTests: XCTestCase {

    func testInitizer() {
        let now = Date()
        var override = GlucoseRangeSchedule.Override(
            value: DoubleRange(minValue: 70, maxValue: 80),
            start: now,
            end: now.addingTimeInterval(TimeInterval.minutes(30)))
        XCTAssertEqual(override.value, DoubleRange(minValue: 70, maxValue: 80))
        XCTAssertEqual(override.start, now)
        XCTAssertEqual(override.end, now.addingTimeInterval(TimeInterval.minutes(30)))

        override = GlucoseRangeSchedule.Override(
            value: DoubleRange(minValue: 70, maxValue: 80),
            start: now)
        XCTAssertEqual(override.end, .distantFuture)
    }

    func testActiveDates() {
        let duration = TimeInterval.hours(24)
        let start = Date()
        let end = start.addingTimeInterval(duration)

        let override = GlucoseRangeSchedule.Override(
            value: DoubleRange(minValue: 70, maxValue: 80),
            start: start,
            end: end)

        XCTAssertEqual(override.activeDates.start, start)
        XCTAssertEqual(override.activeDates.end, end)
        XCTAssertEqual(override.activeDates.duration, duration)
    }

    func testIsActiveAtDate() {
        let duration = TimeInterval.hours(24)
        let start = Date()
        let end = start.addingTimeInterval(duration)

        let override = GlucoseRangeSchedule.Override(
            value: DoubleRange(minValue: 70, maxValue: 80),
            start: start,
            end: end)

        XCTAssertTrue(override.isActive(at: start.addingTimeInterval(duration/2)))
        XCTAssertFalse(override.isActive(at: start.addingTimeInterval(duration*2)))
    }
}
