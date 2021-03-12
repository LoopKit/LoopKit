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

    func testConvertTo() {
        let glucoseThresholdMMOLL = GlucoseThreshold(unit: .millimolesPerLiter, value: 4.4)
        let glucoseThresholdMGDL = glucoseThresholdMMOLL.convertTo(unit: .milligramsPerDeciliter)
        XCTAssertEqual(glucoseThresholdMGDL?.unit, .milligramsPerDeciliter)
        XCTAssertEqual(glucoseThresholdMGDL?.value, HKQuantity(unit: .millimolesPerLiter, doubleValue: glucoseThresholdMMOLL.value).doubleValue(for: .milligramsPerDeciliter))
    }
}

class GlucoseThresholdCodableTests: XCTestCase {
    func testCodableMilligramsPerDeciliter() throws {
        try assertGlucoseThresholdCodable(GlucoseThreshold(unit: .milligramsPerDeciliter, value: 123),
                                          encodesJSON: """
{
  "unit" : "mg/dL",
  "value" : 123
}
"""
        )
    }

    func testCodableMillimolesPerLiter() throws {
        try assertGlucoseThresholdCodable(GlucoseThreshold(unit: .millimolesPerLiter, value: 6.5),
                                          encodesJSON: """
{
  "unit" : "mmol<180.1558800000541>/L",
  "value" : 6.5
}
"""
        )
    }

    private func assertGlucoseThresholdCodable(_ original: GlucoseThreshold, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(GlucoseThreshold.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()
}
