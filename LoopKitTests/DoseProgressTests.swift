//
//  DoseProgressTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2020-11-25.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class DoseProgressTests: XCTestCase {

    func testIsCompleted() {
        var doseProgress = DoseProgress(deliveredUnits: 0, percentComplete: 0)
        XCTAssertFalse(doseProgress.isComplete)

        doseProgress = DoseProgress(deliveredUnits: 0, percentComplete: 0.5)
        XCTAssertFalse(doseProgress.isComplete)

        doseProgress = DoseProgress(deliveredUnits: 0, percentComplete: 0.9999999999999999) // less than ulpOfOne from 1
        XCTAssertTrue(doseProgress.isComplete)

        doseProgress = DoseProgress(deliveredUnits: 0, percentComplete: 1)
        XCTAssertTrue(doseProgress.isComplete)

        doseProgress = DoseProgress(deliveredUnits: 0, percentComplete: 2)
        XCTAssertTrue(doseProgress.isComplete)
    }
}
