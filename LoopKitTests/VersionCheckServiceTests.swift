//
//  VersionCheckServiceTests.swift
//  LoopKitTests
//
//  Created by Rick Pasetto on 9/13/21.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class VersionCheckServiceTests: XCTestCase {

    func testVersionUpdateOrder() throws {
        // Comparable order is important for VersionUpdate.  Do not reorder!
        XCTAssertGreaterThan(VersionUpdate.criticalNeeded, VersionUpdate.supportedNeeded)
        XCTAssertGreaterThan(VersionUpdate.supportedNeeded, VersionUpdate.noneNeeded)
    }

}
