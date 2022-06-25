//
//  QuantityScheduleTests.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class QuantityScheduleTests: XCTestCase {

    var items: [RepeatingScheduleValue<Double>]!

    override func setUp() {
        super.setUp()

        let path = Bundle(for: type(of: self)).path(forResource: "read_carb_ratios", ofType: "json")!
        let fixture = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path)), options: []) as! JSONDictionary
        let schedule = fixture["schedule"] as! [JSONDictionary]

        items = schedule.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["offset"] as! Double), value: $0["ratio"] as! Double)
        }
    }

    func testCarbRatioScheduleLocalTimeZone() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -6*60*60)!
        let schedule = CarbRatioSchedule(unit: HKUnit.gram(), dailyItems: items, timeZone: therapyTimeZone)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone

        let midnight = calendar.startOfDay(for: Date())

        XCTAssertEqual(HKQuantity(unit: HKUnit.gram(), doubleValue: 10), schedule.quantity(at: midnight))
        XCTAssertEqual(9,
            schedule.quantity(at: midnight.addingTimeInterval(-1)).doubleValue(for: schedule.unit)
        )
        XCTAssertEqual(10,
            schedule.quantity(at: midnight.addingTimeInterval(TimeInterval(hours: 24))).doubleValue(for: schedule.unit)
        )

        let midMorning = calendar.nextDate(after: Date(), matching: DateComponents(hour: 10, minute: 29, second: 4), matchingPolicy: .nextTime)!

        XCTAssertEqual(10, schedule.quantity(at: midMorning).doubleValue(for: schedule.unit))

        let lunch = calendar.nextDate(after: midMorning, matching: DateComponents(hour: 12, minute: 01, second: 01), matchingPolicy: .nextTime)!

        XCTAssertEqual(9, schedule.quantity(at: lunch).doubleValue(for: schedule.unit))

        let dinner = calendar.nextDate(after: midMorning, matching: DateComponents(hour: 19, minute: 0, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(8, schedule.quantity(at: dinner).doubleValue(for: schedule.unit))
    }

    func testCarbRatioScheduleUTC() {
        let schedule = CarbRatioSchedule(unit: HKUnit.gram(), dailyItems: items, timeZone: TimeZone(secondsFromGMT: 0))!
        var calendar = Calendar.current

        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let june1 = calendar.nextDate(after: Date(), matching: DateComponents(month: 5), matchingPolicy: .nextTime)!

        XCTAssertEqual(-7 * 60 * 60, calendar.timeZone.secondsFromGMT(for: june1))


        let midnight = calendar.startOfDay(for: june1)

        // This is 7 AM the next day in the Schedule's time zone
        XCTAssertEqual(HKQuantity(unit: HKUnit.gram(), doubleValue: 10), schedule.quantity(at: midnight))
        XCTAssertEqual(10,
            schedule.quantity(at: midnight.addingTimeInterval(-1)).doubleValue(for: schedule.unit)
        )
        XCTAssertEqual(10,
            schedule.quantity(at: midnight.addingTimeInterval(TimeInterval(hours: 24))).doubleValue(for: schedule.unit)
        )

        // 10:29:04 AM -> 5:29:04 PM
        let midMorning = calendar.nextDate(after: june1, matching: DateComponents(hour: 10, minute: 29, second: 4), matchingPolicy: .nextTime)!

        XCTAssertEqual(9, schedule.quantity(at: midMorning).doubleValue(for: schedule.unit))

        // 12:01:01 PM -> 7:01:01 PM
        let lunch = calendar.nextDate(after: midMorning, matching: DateComponents(hour: 12, minute: 01, second: 01), matchingPolicy: .nextTime)!

        XCTAssertEqual(8, schedule.quantity(at: lunch).doubleValue(for: schedule.unit))

        // 7:00 PM -> 2:00 AM
        let dinner = calendar.nextDate(after: midMorning, matching: DateComponents(hour: 19, minute: 0, second: 0), matchingPolicy: .nextTime)!

        XCTAssertEqual(10, schedule.quantity(at: dinner).doubleValue(for: schedule.unit))
    }

    

}
