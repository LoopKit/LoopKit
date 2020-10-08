//
//  TempBasalRecommendationTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 7/27/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest

@testable import LoopKit

class TempBasalRecommendationTests: XCTestCase {
    
    func testCancel() {
        let cancel = TempBasalRecommendation.cancel
        XCTAssertEqual(cancel.unitsPerHour, 0)
        XCTAssertEqual(cancel.duration, 0)
    }
    
    func testInitializer() {
        let tempBasalRecommendation = TempBasalRecommendation(unitsPerHour: 1.23, duration: 4.56)
        XCTAssertEqual(tempBasalRecommendation.unitsPerHour, 1.23)
        XCTAssertEqual(tempBasalRecommendation.duration, 4.56)
    }
    
}
