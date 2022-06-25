//
//  GlucoseRangeScheduleTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-09.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class GlucoseRangeScheduleTests: XCTestCase {

    func testInitializer() {
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ],
            timeZone: TimeZone(secondsFromGMT: -14400))
        XCTAssertNotNil(glucoseRangeSchedule)
        XCTAssertEqual(glucoseRangeSchedule!.unit, .milligramsPerDeciliter)
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items.count, 3)
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[0].startTime, 0)
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[0].value, DoubleRange(minValue: 75.0, maxValue: 90.0))
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[1].startTime, 3000)
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[1].value, DoubleRange(minValue: 100.0, maxValue: 120.0))
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[2].startTime, 6000)
        XCTAssertEqual(glucoseRangeSchedule!.rangeSchedule.items[2].value, DoubleRange(minValue: 130.0, maxValue: 150.0))
        XCTAssertEqual(glucoseRangeSchedule!.timeZone, TimeZone(secondsFromGMT: -14400))
        XCTAssertEqual(glucoseRangeSchedule!.minLowerBound(), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75))
        XCTAssertEqual(glucoseRangeSchedule!.scheduleRange(), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 150))
    }

    func testInitializerWithOverride() {
        let schedule = DailyQuantitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ])!
        let override = GlucoseRangeSchedule.Override(
            value: DoubleRange(minValue: 90.0, maxValue: 110.0),
            start: Date())

        let glucoseRangeSchedule = GlucoseRangeSchedule(
            rangeSchedule: schedule,
            override: override)
        XCTAssertNotNil(glucoseRangeSchedule)
        XCTAssertEqual(glucoseRangeSchedule.unit, .milligramsPerDeciliter)
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items.count, 3)
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[0].startTime, 0)
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[0].value, DoubleRange(minValue: 75.0, maxValue: 90.0))
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[1].startTime, 3000)
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[1].value, DoubleRange(minValue: 100.0, maxValue: 120.0))
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[2].startTime, 6000)
        XCTAssertEqual(glucoseRangeSchedule.rangeSchedule.items[2].value, DoubleRange(minValue: 130.0, maxValue: 150.0))
        XCTAssertEqual(glucoseRangeSchedule.override, override)
    }

    func testRawValue() {
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0))
            ])
        XCTAssertNotNil(glucoseRangeSchedule)
        XCTAssertEqual(glucoseRangeSchedule!.rawValue["unit"] as! String, "mg/dL")
        XCTAssertEqual((glucoseRangeSchedule!.rawValue["items"] as! [[String: Any]]).count, 1)
        XCTAssertEqual((glucoseRangeSchedule!.rawValue["items"] as! [[String: Any]])[0]["value"] as! [Double], [75.0, 90.0])
        XCTAssertEqual((glucoseRangeSchedule!.rawValue["items"] as! [[String: Any]])[0]["startTime"] as! Double, 0.0)
    }

    func testInitializerWithRawValueValid() {
        let rawValue: GlucoseRangeSchedule.RawValue = [
            "timeZone": -14400,
            "unit": "mg/dL",
            "items": [
                [
                    "startTime": 0.0,
                    "value": [
                        75.0,
                        90.0
                    ]
                ]
            ]
        ]

        let glucoseRangeSchedule = GlucoseRangeSchedule(rawValue: rawValue)
        XCTAssertNotNil(glucoseRangeSchedule)
        XCTAssertEqual(glucoseRangeSchedule!.items, [RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0))])
        XCTAssertEqual(glucoseRangeSchedule!.unit, .milligramsPerDeciliter)
        XCTAssertEqual(glucoseRangeSchedule!.timeZone, TimeZone(secondsFromGMT: -14400))
    }

    func testInitializerWithRawValueWithValueMissing() {
        let rawValue: GlucoseRangeSchedule.RawValue = [
            "timeZone": -14400,
            "unit": "mg/dL"
        ]

        XCTAssertNil(GlucoseRangeSchedule(rawValue: rawValue))
    }

    func testInitializerWithRawValueWithWrongType() {
        let rawValue: GlucoseRangeSchedule.RawValue = [
            "units": "g",
            "timeZone": "g",
            "items": [
                [
                    "startTime": 0,
                    "value": [
                        75,
                        90
                    ]
                ]
            ]
        ]
        XCTAssertNil(GlucoseRangeSchedule(rawValue: rawValue))
    }

    func testInitializerWithRawValueWithUnitMissing() {
        let rawValue: GlucoseRangeSchedule.RawValue = [
            "timeZone": -14400,
            "items": [
                [
                    "startTime": 0.0,
                    "value": [
                        75.0,
                        90.0
                    ]
                ]
            ]
        ]
        XCTAssertNil(GlucoseRangeSchedule(rawValue: rawValue))
    }

    func testBetweenStartEnd() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -4*60*60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ], timeZone: therapyTimeZone)
        let start = calendar.startOfDay(for: Date())
        let end = start.addingTimeInterval(TimeInterval.minutes(30))
        let expected = [AbsoluteScheduleValue(startDate: start, endDate: start.addingTimeInterval(TimeInterval.minutes(50)), value: DoubleRange(minValue: 75.0, maxValue: 90.0))]

        XCTAssertEqual(glucoseRangeSchedule!.between(start: start, end: end), expected)
    }

    func testQuantityBetweenStartEnd() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -4*60*60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .millimolesPerLiter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ], timeZone: therapyTimeZone)
        let start = calendar.startOfDay(for: Date())
        let end = start.addingTimeInterval(TimeInterval.minutes(30))
        let expected = [AbsoluteScheduleValue(startDate: start, endDate: start.addingTimeInterval(TimeInterval.minutes(50)), value: DoubleRange(minValue: 75.0, maxValue: 90.0).quantityRange(for: .millimolesPerLiter))]

        XCTAssertEqual(glucoseRangeSchedule!.quantityBetween(start: start, end: end), expected)
    }

    func testValueAtDate() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -4*60*60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ], timeZone: therapyTimeZone)
        let inDay30Min = calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval.minutes(30))
        let inDay1Hour = inDay30Min.addingTimeInterval(TimeInterval.minutes(30))
        let inDay2Hours = inDay1Hour.addingTimeInterval(TimeInterval.minutes(60))

        XCTAssertEqual(glucoseRangeSchedule!.value(at: inDay30Min), DoubleRange(minValue: 75.0, maxValue: 90.0))
        XCTAssertEqual(glucoseRangeSchedule!.value(at: inDay1Hour), DoubleRange(minValue: 100.0, maxValue: 120.0))
        XCTAssertEqual(glucoseRangeSchedule!.value(at: inDay2Hours), DoubleRange(minValue: 130.0, maxValue: 150.0))
    }

    func testQuantityRangeAtDate() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -4*60*60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone
        let glucoseRangeSchedule = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
                RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
                RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
            ], timeZone: therapyTimeZone)
        let inDay30Min = calendar.startOfDay(for: Date()).addingTimeInterval(TimeInterval.minutes(30))
        let inDay1Hour = inDay30Min.addingTimeInterval(TimeInterval.minutes(30))
        let inDay2Hours = inDay1Hour.addingTimeInterval(TimeInterval.minutes(60))

        XCTAssertEqual(glucoseRangeSchedule!.quantityRange(at: inDay30Min), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 75.0)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 90.0))
        XCTAssertEqual(glucoseRangeSchedule!.quantityRange(at: inDay1Hour), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 100.0)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 120.0))
        XCTAssertEqual(glucoseRangeSchedule!.quantityRange(at: inDay2Hours), HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 130.0)...HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 150.0))
    }

    func testScheduleFor() {
        let therapyTimeZone = TimeZone(secondsFromGMT: -4*60*60)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = therapyTimeZone
        let glucoseRangeScheduleMGDL = GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems:  [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0))
            ], timeZone: therapyTimeZone)
        let glucoseRangeScheduleMMOLL = glucoseRangeScheduleMGDL?.schedule(for: .millimolesPerLiter)
        let expected = DoubleRange(minValue: 75.0, maxValue: 90.0).quantityRange(for: .milligramsPerDeciliter).doubleRange(for: .millimolesPerLiter)

        XCTAssertNotNil(glucoseRangeScheduleMMOLL)
        XCTAssertEqual(glucoseRangeScheduleMMOLL!.unit, .millimolesPerLiter)
        XCTAssertEqual(glucoseRangeScheduleMMOLL!.rangeSchedule.items[0].value, expected)
    }

    func testInitializeClosedHKQuantityRange() throws {
        let dailyItems = [
            RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
            RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
            RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
        ]
        let dailyQuantities = dailyItems.map {
            RepeatingScheduleValue(startTime: $0.startTime,
                                   value: $0.value.quantityRange(for: .milligramsPerDeciliter))
        }
        let rangeSchedule = DailyQuantitySchedule(
            unit: .milligramsPerDeciliter,
            dailyQuantities: dailyQuantities)!
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(rangeSchedule: rangeSchedule)

        XCTAssertEqual(glucoseTargetRangeSchedule.rangeSchedule, rangeSchedule)
    }

    func testQuantityRanges() throws {
        let dailyItems = [
            RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 75.0, maxValue: 90.0)),
            RepeatingScheduleValue(startTime: 3000, value: DoubleRange(minValue: 100.0, maxValue: 120.0)),
            RepeatingScheduleValue(startTime: 6000, value: DoubleRange(minValue: 130.0, maxValue: 150.0))
        ]
        let dailyQuantities = dailyItems.map {
            RepeatingScheduleValue(startTime: $0.startTime,
                                   value: $0.value.quantityRange(for: .milligramsPerDeciliter))
        }
        let glucoseTargetRangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: dailyItems)!
        XCTAssertEqual(glucoseTargetRangeSchedule.quantityRanges, dailyQuantities)
    }
}

