//
//  InsulinSensitivityScheduleTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class InsulinSensitivityScheduleTests: XCTestCase {

    func testScheduleFor() {
        // Values that survive the mg/dL -> mmol/L -> mg/dL round trip with rounding
        let value1 = 18.0
        let value2 = 40.0
        let timeZone = TimeZone(secondsFromGMT: 0)!
        let insulinSensitivityScheduleMGDL = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: value1),
                RepeatingScheduleValue(startTime: 1000, value: value2)
            ],
            timeZone: timeZone)
        let insulinSensitivityScheduleMMOLL = InsulinSensitivitySchedule(
            unit: .millimolesPerLiter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0,
                                       value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value1).doubleValue(for: .millimolesPerLiter, withRounding: true)),
                RepeatingScheduleValue(startTime: 1000,
                                       value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value2).doubleValue(for: .millimolesPerLiter, withRounding: true))
            ],
            timeZone: timeZone)
        XCTAssertEqual(insulinSensitivityScheduleMGDL!.schedule(for: .millimolesPerLiter), insulinSensitivityScheduleMMOLL!)

        for date in [Date(timeIntervalSinceReferenceDate: 500), Date(timeIntervalSinceReferenceDate: 2000)] {
            XCTAssertEqual(insulinSensitivityScheduleMGDL!.value(at: date), insulinSensitivityScheduleMMOLL!.value(for: .milligramsPerDeciliter, at: date))
            XCTAssertEqual(insulinSensitivityScheduleMGDL!.value(at: date), insulinSensitivityScheduleMGDL!.value(for: .milligramsPerDeciliter, at: date))
        }
    }
}
