//
//  HKUnitTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class HKUnitTests: XCTestCase {

    func testPreferredFractionDigits() throws {
        XCTAssertEqual(HKUnit.millimolesPerLiter.preferredFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()).preferredFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .minute()).preferredFractionDigits, 1)

        XCTAssertEqual(HKUnit.gram().preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.gram().unitDivided(by: .internationalUnit()).preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()).preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .minute()).preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.internationalUnit().preferredFractionDigits, 0)
        XCTAssertEqual(HKUnit.internationalUnit().unitDivided(by: .hour()).preferredFractionDigits, 0)
    }

    func testRoundValue() throws {
        XCTAssertEqual(HKUnit.millimolesPerLiter.roundForPreferredDigits(value: 1.34), 1.3)
        XCTAssertEqual(HKUnit.millimolesPerLiter.roundForPicker(value: 2.56), 2.6)

        XCTAssertEqual(HKUnit.milligramsPerDeciliter.roundForPreferredDigits(value: 1.34), 1)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.roundForPicker(value: 2.56), 3)
    }

    func testMaxFractionDigits() throws {
        XCTAssertEqual(HKUnit.internationalUnit().maxFractionDigits, 3)
        XCTAssertEqual(HKUnit.internationalUnit().unitDivided(by: .hour()).maxFractionDigits, 3)

        XCTAssertEqual(HKUnit.millimolesPerLiter.maxFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()).maxFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .minute()).maxFractionDigits, 1)
        XCTAssertEqual(HKUnit.gram().unitDivided(by: .internationalUnit()).maxFractionDigits, 1)

        XCTAssertEqual(HKUnit.gram().maxFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.maxFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()).maxFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .minute()).maxFractionDigits, 0)
    }

    func testPickerFractionDigits() throws {
        XCTAssertEqual(HKUnit.internationalUnit().pickerFractionDigits, 3)
        XCTAssertEqual(HKUnit.internationalUnit().unitDivided(by: .hour()).pickerFractionDigits, 3)

        XCTAssertEqual(HKUnit.millimolesPerLiter.pickerFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .internationalUnit()).pickerFractionDigits, 1)
        XCTAssertEqual(HKUnit.millimolesPerLiter.unitDivided(by: .minute()).pickerFractionDigits, 1)
        XCTAssertEqual(HKUnit.gram().unitDivided(by: .internationalUnit()).pickerFractionDigits, 1)

        XCTAssertEqual(HKUnit.gram().pickerFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.pickerFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .internationalUnit()).pickerFractionDigits, 0)
        XCTAssertEqual(HKUnit.milligramsPerDeciliter.unitDivided(by: .minute()).pickerFractionDigits, 0)
    }
}
