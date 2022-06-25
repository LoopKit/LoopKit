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
        let value1 = 15.0
        let value2 = 40.0
        let insulinSensitivityScheduleMGDL = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: value1),
                RepeatingScheduleValue(startTime: 1000, value: value2)
            ])
        let insulinSensitivityScheduleMMOLL = InsulinSensitivitySchedule(
            unit: .millimolesPerLiter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0,
                                       value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value1).doubleValue(for: .millimolesPerLiter)),
                RepeatingScheduleValue(startTime: 1000,
                                       value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: value2).doubleValue(for: .millimolesPerLiter))
            ])
        XCTAssertEqual(insulinSensitivityScheduleMGDL!.schedule(for: .millimolesPerLiter), insulinSensitivityScheduleMMOLL!)
    }
}
