//
//  BasalRateScheduleTests.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import LoopKit


func ==<T: Equatable>(lhs: RepeatingScheduleValue<T>, rhs: RepeatingScheduleValue<T>) -> Bool {
    return lhs.startTime == rhs.startTime && lhs.value == rhs.value
}

func ==<T: Equatable>(lhs: AbsoluteScheduleValue<T>, rhs: AbsoluteScheduleValue<T>) -> Bool {
    return lhs.startDate == rhs.startDate && lhs.endDate == rhs.endDate && lhs.value == rhs.value
}


func ==<T: Equatable>(lhs: ArraySlice<AbsoluteScheduleValue<T>>, rhs: ArraySlice<AbsoluteScheduleValue<T>>) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }

    for (l, r) in zip(lhs, rhs) {
        if !(l == r) {
            return false
        }
    }

    return true
}


class BasalRateScheduleTests: XCTestCase {
    
    var items: [RepeatingScheduleValue<Double>]!

    override func setUp() {
        super.setUp()

        let path = Bundle(for: type(of: self)).path(forResource: "basal", ofType: "json")!
        let fixture = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! [JSONDictionary]

        items = fixture.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["minutes"] as! Double), value: $0["rate"] as! Double)
        }
    }

    func testBasalScheduleRanges() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -6*60*60)!
        let schedule = BasalRateSchedule(dailyItems: items, timeZone: therapyTimeZone)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone

        let midnight = calendar.startOfDay(for: Date())

        var absoluteItems: [AbsoluteScheduleValue<Double>] = (0..<items.count).map {
            let endTime = ($0 + 1) < items.count ? items[$0 + 1].startTime : .hours(24)
            return AbsoluteScheduleValue(
                startDate: midnight.addingTimeInterval(items[$0].startTime),
                endDate: midnight.addingTimeInterval(endTime),
                value: items[$0].value
            )
        }

        absoluteItems += (0..<items.count).map {
            let endTime = ($0 + 1) < items.count ? items[$0 + 1].startTime : .hours(24)
            return AbsoluteScheduleValue(
                startDate: midnight.addingTimeInterval(items[$0].startTime + .hours(24)),
                endDate: midnight.addingTimeInterval(endTime + .hours(24)),
                value: items[$0].value
            )
        }

        XCTAssert(
            absoluteItems[0..<items.count] ==
            schedule.between(
                start: midnight,
                end: midnight.addingTimeInterval(TimeInterval(hours: 24))
            )[0..<items.count]
        )

        let twentyThree30 = midnight.addingTimeInterval(TimeInterval(hours: 23)).addingTimeInterval(TimeInterval(minutes: 30))

        XCTAssert(
            absoluteItems[0..<items.count] ==
            schedule.between(
                start: midnight,
                end: twentyThree30
            )[0..<items.count]
        )

        XCTAssert(
            absoluteItems[0..<items.count + 1] ==
            schedule.between(
                start: midnight,
                end: midnight.addingTimeInterval(TimeInterval(hours: 24) + TimeInterval(1))
            )[0..<items.count + 1]
        )

        XCTAssert(
            absoluteItems[items.count - 1..<items.count * 2] ==
            schedule.between(
                start: twentyThree30,
                end: twentyThree30.addingTimeInterval(TimeInterval(hours: 24))
            )[0..<items.count + 1]
        )

        XCTAssert(
            absoluteItems[0..<1] ==
            schedule.between(
                start: midnight,
                end: midnight.addingTimeInterval(TimeInterval(hours: 1))
            )[0..<1]
        )

        XCTAssert(
            absoluteItems[1..<3] ==
            schedule.between(
                start: midnight.addingTimeInterval(TimeInterval(hours: 4)),
                end: midnight.addingTimeInterval(TimeInterval(hours: 9))
            )[0..<2]
        )

        XCTAssert(
            absoluteItems[5..<6] ==
            schedule.between(
                start: midnight.addingTimeInterval(TimeInterval(hours: 16)),
                end: midnight.addingTimeInterval(TimeInterval(hours: 20))
            )[0..<1]
        )

        XCTAssert(
            schedule.between(
                start: midnight.addingTimeInterval(TimeInterval(hours: 4)),
                end: midnight.addingTimeInterval(TimeInterval(hours: 3))
            ).isEmpty
        )
    }

    func testTotalDelivery() {
        let schedule = BasalRateSchedule(dailyItems: items, timeZone: nil)!

        XCTAssertEqual(20.275, schedule.total(), accuracy: 1e-14)
    }

    func testRawValueSerialization() {
        let schedule = BasalRateSchedule(dailyItems: items, timeZone: nil)!
        let reSchedule = BasalRateSchedule(rawValue: schedule.rawValue)!

        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())

        XCTAssertEqual(reSchedule.timeZone.secondsFromGMT(), schedule.timeZone.secondsFromGMT())
        XCTAssertEqual(reSchedule.value(at: midnight), schedule.value(at: midnight))

        let threethirty = midnight.addingTimeInterval(TimeInterval(hours: 3.5))

        XCTAssertEqual(reSchedule.value(at: threethirty), schedule.value(at: threethirty))

        let fourthirty = midnight.addingTimeInterval(TimeInterval(hours: 4.5))

        XCTAssertEqual(reSchedule.value(at: fourthirty), schedule.value(at: fourthirty))
    }

}
