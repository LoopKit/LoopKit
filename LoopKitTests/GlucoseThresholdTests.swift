//
//  GlucoseThresholdTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 8/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class GlucoseThresholdTests: XCTestCase {
    
    func testInitializer() {
        let glucoseThreshold = GlucoseThreshold(unit: HKUnit.gram(), value: 1.23)
        XCTAssertEqual(glucoseThreshold.value, 1.23)
        XCTAssertEqual(glucoseThreshold.unit, HKUnit.gram())
    }
    
    func testInitializerWithRawValueValid() {
        let rawValue: GlucoseThreshold.RawValue = [
            "units": "g",
            "value": 1.23
        ]
        let glucoseThreshold = GlucoseThreshold(rawValue: rawValue)
        XCTAssertNotNil(glucoseThreshold)
        XCTAssertEqual(glucoseThreshold!.value, 1.23)
        XCTAssertEqual(glucoseThreshold!.unit, HKUnit.gram())
    }
    
    func testInitializerWithRawValueWithValueMissing() {
        let rawValue: GlucoseThreshold.RawValue = [
            "units": "g"
        ]
        XCTAssertNil(GlucoseThreshold(rawValue: rawValue))
    }
    
    func testInitializerWithRawValueWithValueNotDouble() {
        let rawValue: GlucoseThreshold.RawValue = [
            "units": "g",
            "value": "g"
        ]
        XCTAssertNil(GlucoseThreshold(rawValue: rawValue))
    }
    
    func testInitializerWithRawValueWithUnitMissing() {
        let rawValue: GlucoseThreshold.RawValue = [
            "value": 1.23
        ]
        XCTAssertNil(GlucoseThreshold(rawValue: rawValue))
    }
    
    func testInitializerWithRawValueWithUnitNotString() {
        let rawValue: GlucoseThreshold.RawValue = [
            "units": 1.23,
            "value": 1.23
        ]
        XCTAssertNil(GlucoseThreshold(rawValue: rawValue))
    }
    
    func testQuantity() {
        let glucoseThreshold = GlucoseThreshold(unit: HKUnit.gram(), value: 1.23)
        XCTAssertEqual(glucoseThreshold.quantity, HKQuantity(unit: HKUnit.gram(), doubleValue: 1.23))
    }
    
    func testRawValue() {
        let glucoseThreshold = GlucoseThreshold(unit: HKUnit.gram(), value: 1.23)
        XCTAssertEqual(glucoseThreshold.rawValue.count, 2)
        XCTAssertEqual(glucoseThreshold.rawValue["units"] as! String, "g")
        XCTAssertEqual(glucoseThreshold.rawValue["value"] as! Double, 1.23)
    }
    
}
