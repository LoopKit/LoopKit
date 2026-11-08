//
//  DisplayGlucosePreferenceTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import LoopKitUI

class DisplayGlucosePreferenceTests: XCTestCase {

    func testUnitChangeKeepsNotANumberSymbol() {
        let preference = DisplayGlucosePreference(displayGlucoseUnit: .milligramsPerDeciliter)

        preference.unitDidChange(to: .millimolesPerLiter)
        XCTAssertEqual(preference.formatter.numberFormatter.notANumberSymbol, "–")

        preference.unitDidChange(to: .milligramsPerDeciliter)
        XCTAssertEqual(preference.formatter.numberFormatter.notANumberSymbol, "–")
    }
}
