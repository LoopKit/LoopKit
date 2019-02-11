//
//  TemporaryScheduleOverrideTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


extension /* BasalRateSchedule */ DailyValueSchedule where T == Double {
    func equals(_ other: BasalRateSchedule, accuracy epsilon: Double) -> Bool {
        guard items.count == other.items.count else { return false }
        return zip(items, other.items).allSatisfy { thisItem, otherItem in
            abs(thisItem.value - otherItem.value) <= epsilon
        }
    }
}

class TemporaryScheduleOverrideTests: XCTestCase {

    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    let epsilon = 1e-5

    let basalRateSchedule = BasalRateSchedule(dailyItems: [
        RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
        RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
        RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
    ])!

    private func date(at time: String) -> Date {
        return dateFormatter.date(from: "2019-01-01T\(time):00")!
    }

    private func basalUpOverride(start: String, end: String) -> TemporaryScheduleOverride {
        return TemporaryScheduleOverride(
            context: .custom,
            settings: TemporaryScheduleOverrideSettings(
                targetRange: DoubleRange(minValue: 0, maxValue: 0),
                basalRateMultiplier: 1.5
            ),
            startDate: date(at: start),
            duration: .finite(date(at: end).timeIntervalSince(date(at: start)))
        )
    }

    private func applyingActiveBasalOverride(from start: String, to end: String, on schedule: BasalRateSchedule, referenceDate: Date? = nil) -> BasalRateSchedule {
        let override = basalUpOverride(start: start, end: end)
        let referenceDate = referenceDate ?? override.activeInterval.midpoint
        return schedule.applyingBasalRateMultiplier(from: override, relativeTo: referenceDate)
    }

    // Override start aligns with schedule item start
    func testBasalRateScheduleOverrideStartTimeMatch() {
        let overrideBasalSchedule = applyingActiveBasalOverride(from: "00:00", to: "01:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(1), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overrideBasalSchedule.equals(expected, accuracy: epsilon))
    }

    // Override contained fully within a schedule item
    func testBasalRateScheduleOverrideContained() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override end aligns with schedule item start
    func testBasalRateScheduleOverrideEndTimeMatch() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "06:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override completely encapsulates schedule item
    func testBasalRateScheduleOverrideEncapsulate() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "22:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testSingleBasalRateSchedule() {
        let basalRateSchedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0)
        ])!
        let overridden = applyingActiveBasalOverride(from: "08:00", to: "12:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(12), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testOverrideCrossingMidnight() {
        var override = basalUpOverride(start: "22:00", end: "23:00")
        override.duration += .hours(5)
        // override goes from 10pm to 4am of the next day
        let overriddenFirstDay = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "22:00"))
        let expectedFirstDay = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.5)
        ])!
        XCTAssert(overriddenFirstDay.equals(expectedFirstDay, accuracy: epsilon))

        let overridenSecondDay = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "22:00") + .hours(3))
        let expectedSecondDay = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0),
        ])!
        XCTAssert(overridenSecondDay.equals(expectedSecondDay, accuracy: epsilon))
    }

    func testMultiDayOverride() {
        var override = basalUpOverride(start: "02:00", end: "22:00")
        override.duration += .hours(48)
        // override goes from 2am until 10pm two days later
        let overrideBasalSchedule = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "02:00") + .hours(24))
        // expect full schedule overridden for middle day
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(overrideBasalSchedule.equals(expected, accuracy: epsilon))
    }

    func testSameDayFinishedOverride() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule, referenceDate: date(at: "12:00"))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testPreviousDayFinishedOverride() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule, referenceDate: date(at: "12:00") + .hours(-24))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testNextDayNotYetStartedOverride() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule, referenceDate: date(at: "12:00") + .hours(24))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }
}

private extension DateInterval {
    var midpoint: Date {
        return Date(timeIntervalSince1970: (start.timeIntervalSince1970 + end.timeIntervalSince1970) / 2)
    }
}

private extension TemporaryScheduleOverride.Duration {
    static func += (lhs: inout TemporaryScheduleOverride.Duration, rhs: TimeInterval) {
        switch lhs {
        case .finite(let interval):
            lhs = .finite(interval + rhs)
        case .indefinite:
            return
        }
    }
}
