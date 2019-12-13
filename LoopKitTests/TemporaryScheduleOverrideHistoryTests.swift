//
//  TemporaryScheduleOverrideHistoryTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit


final class TemporaryScheduleOverrideHistoryTests: XCTestCase {
    // Midnight of an arbitrary date
    let referenceDate = Calendar.current.startOfDay(for: Date(timeIntervalSinceReferenceDate: .hours(100_000)))

    let basalRateSchedule = BasalRateSchedule(
        dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ],
        timeZone: Calendar.current.timeZone
    )!

    let history = TemporaryScheduleOverrideHistory()

    private func recordOverride(
        beginningAt offset: TimeInterval,
        duration: TemporaryScheduleOverride.Duration,
        insulinNeedsScaleFactor scaleFactor: Double,
        recordedAt enableDateOffset: TimeInterval? = nil
    ) {
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: nil, insulinNeedsScaleFactor: scaleFactor)
        let override = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: referenceDate + offset, duration: duration, enactTrigger: .local, syncIdentifier: UUID())
        let enableDate: Date
        if let enableDateOffset = enableDateOffset {
            enableDate = referenceDate + enableDateOffset
        } else {
            enableDate = override.startDate
        }
        history.recordOverride(override, at: enableDate)
    }

    private func recordOverrideDisable(at offset: TimeInterval) {
        history.recordOverride(nil, at: referenceDate + offset)
    }

    private func historyResolves(to expected: BasalRateSchedule, referenceDateOffset: TimeInterval = 0) -> Bool {
        let referenceDate = self.referenceDate + referenceDateOffset
        let actual = history.resolvingRecentBasalSchedule(basalRateSchedule, relativeTo: referenceDate)
        return actual.equals(expected, accuracy: 1e-6)
    }

    override func setUp() {
        history.wipeHistory()
    }

    func testEmptyHistory() {
        XCTAssert(historyResolves(to: basalRateSchedule))
    }

    func testSingleOverrideNaturalEnd() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testSingleOverrideEarlyEnd() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(3))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(3), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testSingleIndefiniteOverrideEarlyEnd() {
        recordOverride(beginningAt: .hours(2), duration: .indefinite, insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(3))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(3), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(3)))
    }

    func testTwoOverrides() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverride(beginningAt: .hours(6), duration: .finite(.hours(4)), insulinNeedsScaleFactor: 2.0)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(10), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(10)))
    }

    func testThreeOverrides() {
        recordOverride(beginningAt: .hours(5), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(6))
        recordOverride(beginningAt: .hours(10), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0)
        recordOverride(beginningAt: .hours(12), duration: .finite(.hours(2)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(13))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(10), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(11), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(12), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(13), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(13)))
    }

    func testOldOverrideRemoval() {
        recordOverride(beginningAt: .hours(-1000), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0)
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }

    func testActiveIndefiniteOverride() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5)
        recordOverride(beginningAt: .hours(6), duration: .indefinite, insulinNeedsScaleFactor: 2.0)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(5), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.8),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }

    func testEditActiveOverride() {
        recordOverride(beginningAt: .hours(1), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 1.5, recordedAt: .hours(0))
        recordOverride(beginningAt: .hours(1), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0, recordedAt: .hours(0.5))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(1), value: 2.4),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }

    func testRemoveFutureOverride() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5, recordedAt: .hours(1))
        recordOverride(beginningAt: .hours(1), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 2.0)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(1), value: 2.4),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected))
    }

    func testCancelFutureOverride() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(3)), insulinNeedsScaleFactor: 1.5, recordedAt: .hours(1))
        recordOverrideDisable(at: .hours(1.5))
        let expected = basalRateSchedule
        XCTAssert(historyResolves(to: expected))
    }

    func testMultiDayOverride() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(68)), insulinNeedsScaleFactor: 1.5)

        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(10), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(18), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(26)))
    }

    func testClampedPastOverride() {
        recordOverride(beginningAt: .hours(-4), duration: .finite(.hours(8)), insulinNeedsScaleFactor: 1.5)

        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.5),
        ])!

        print(expected)

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(6)))
    }

    func testCancelSequence() {
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(8)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(4))
        recordOverride(beginningAt: .hours(7), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 1.5)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(7), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(historyResolves(to: expected, referenceDateOffset: .hours(6)))
    }
    
    func testQuery() {
        var (overrides, deletedOverrides, newAnchor) = history.queryByAnchor(nil)
        
        XCTAssertEqual(0, overrides.count)
        XCTAssertEqual(0, deletedOverrides.count)
        
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(8)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(4))
        recordOverride(beginningAt: .hours(7), duration: .finite(.hours(1)), insulinNeedsScaleFactor: 1.5)
        
        (overrides, deletedOverrides, newAnchor) = history.queryByAnchor(newAnchor)
        
        XCTAssertEqual(0, deletedOverrides.count)
        XCTAssertEqual(2, overrides.count)
        
        XCTAssertEqual(TimeInterval(hours: 2), overrides[0].duration.timeInterval, accuracy: 1)
    }

    func testQueryOfDeletedOverrides() {
        var (overrides, deletedOverrides, newAnchor) = history.queryByAnchor(nil)
        
        XCTAssertEqual(0, overrides.count)
        XCTAssertEqual(0, deletedOverrides.count)
        
        recordOverride(beginningAt: .hours(2), duration: .finite(.hours(8)), insulinNeedsScaleFactor: 1.5)
        recordOverrideDisable(at: .hours(1))
        
        (overrides, deletedOverrides, newAnchor) = history.queryByAnchor(newAnchor)
        
        XCTAssertEqual(0, overrides.count)
        XCTAssertEqual(1, deletedOverrides.count)
    }

}
