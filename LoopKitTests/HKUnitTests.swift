//
//  LoopUnitTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-18.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopAlgorithm

@testable import LoopKit

class LoopUnitTests: XCTestCase {

    func testPreferredFractionDigits() throws {
        XCTAssertEqual(LoopUnit.millimolesPerLiter.preferredFractionDigits, 1)
        XCTAssertEqual(LoopUnit.millimolesPerLiterPerInternationalUnit.preferredFractionDigits, 1)
        XCTAssertEqual(LoopUnit.millimolesPerLiterPerMinute.preferredFractionDigits, 1)

        XCTAssertEqual(LoopUnit.gram.preferredFractionDigits, 0)
        XCTAssertEqual(LoopUnit.gramsPerUnit.preferredFractionDigits, 0)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliter.preferredFractionDigits, 0)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliterPerInternationalUnit.preferredFractionDigits, 0)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliterPerMinute.preferredFractionDigits, 1)
        XCTAssertEqual(LoopUnit.internationalUnit.preferredFractionDigits, 0)
        XCTAssertEqual(LoopUnit.internationalUnitsPerHour.preferredFractionDigits, 0)
    }

    func testRoundValue() throws {
        XCTAssertEqual(LoopUnit.millimolesPerLiter.roundForPreferredDigits(value: 1.34), 1.3)
        XCTAssertEqual(LoopUnit.millimolesPerLiter.roundForPicker(value: 2.56), 2.6)

        XCTAssertEqual(LoopUnit.milligramsPerDeciliter.roundForPreferredDigits(value: 1.34), 1)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliter.roundForPicker(value: 2.56), 3)
    }

    func testMaxFractionDigits() throws {
        XCTAssertEqual(LoopUnit.internationalUnit.maxFractionDigits, 3)
        XCTAssertEqual(LoopUnit.internationalUnitsPerHour.maxFractionDigits, 3)

        XCTAssertEqual(LoopUnit.millimolesPerLiter.maxFractionDigits, 1)
        XCTAssertEqual(LoopUnit.millimolesPerLiterPerInternationalUnit.maxFractionDigits, 1)
        XCTAssertEqual(LoopUnit.millimolesPerLiterPerMinute.maxFractionDigits, 1)
        XCTAssertEqual(LoopUnit.gramsPerUnit.maxFractionDigits, 1)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliterPerMinute.maxFractionDigits, 1)

        XCTAssertEqual(LoopUnit.gram.maxFractionDigits, 0)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliter.maxFractionDigits, 0)
        XCTAssertEqual(LoopUnit.milligramsPerDeciliterPerInternationalUnit.maxFractionDigits, 0)
    }
}
