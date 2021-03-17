//
//  GlucoseRangeTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-16.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class GlucoseRangeTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testInitializerDouble() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let glucoseRange = GlucoseRange(
            minValue: 75,
            maxValue: 90,
            unit: unit)
        let expectedRange = DoubleRange(minValue: 75, maxValue: 90)

        XCTAssertEqual(glucoseRange.range, expectedRange)
        XCTAssertEqual(glucoseRange.unit, unit)
    }

    func testInitializerGlucoseRange() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let expectedRange = DoubleRange(minValue: 75, maxValue: 90)
        let glucoseRange = GlucoseRange(
            range: expectedRange,
            unit: unit)

        XCTAssertEqual(glucoseRange.range, expectedRange)
        XCTAssertEqual(glucoseRange.unit, unit)
    }

    func testQuantityRange() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let range = DoubleRange(minValue: 75, maxValue: 90)
        let glucoseRange = GlucoseRange(
            range: range,
            unit: unit)
        let expectedQuantityRange = range.quantityRange(for: unit)
        XCTAssertEqual(glucoseRange.quantityRange, expectedQuantityRange)
    }

    let encodedString = """
    {
      "bloodGlucoseUnit" : "mg/dL",
      "range" : {
        "maxValue" : 90,
        "minValue" : 75
      }
    }
    """

    func testEncoding() throws {
        let glucoseRange = GlucoseRange(
            minValue: 75,
            maxValue: 90,
            unit: .milligramsPerDeciliter)

        let data = try encoder.encode(glucoseRange)
        XCTAssertEqual(encodedString, String(data: data, encoding: .utf8)!)
    }

    func testDecoding() throws {
        let data = encodedString.data(using: .utf8)!
        let decoded = try decoder.decode(GlucoseRange.self, from: data)
        let expected = GlucoseRange(
            minValue: 75,
            maxValue: 90,
            unit: .milligramsPerDeciliter)

        XCTAssertEqual(expected, decoded)
        XCTAssertEqual(decoded.range, expected.range)
        XCTAssertEqual(decoded.unit, expected.unit)
    }

    func testRawValue() throws {
        let glucoseRange = GlucoseRange(
            minValue: 75,
            maxValue: 90,
            unit: .milligramsPerDeciliter)
        var expectedRawValue: [String:Any] = [:]
        expectedRawValue["bloodGlucoseUnit"] = "mg/dL"
        expectedRawValue["range"] = DoubleRange(minValue: 75, maxValue: 90).rawValue

        XCTAssertEqual(glucoseRange.rawValue["bloodGlucoseUnit"] as? String, expectedRawValue["bloodGlucoseUnit"] as? String)
        XCTAssertEqual(glucoseRange.rawValue["range"] as? DoubleRange.RawValue, expectedRawValue["range"] as? DoubleRange.RawValue)
    }

    func testInitializeFromRawValue() throws {
        var rawValue: [String:Any] = [:]
        rawValue["bloodGlucoseUnit"] = "mg/dL"
        rawValue["range"] = DoubleRange(minValue: 80, maxValue: 100).rawValue

        let glucoseRange = GlucoseRange(rawValue: rawValue)
        let expectedRange = DoubleRange(minValue: 80, maxValue: 100)
        XCTAssertEqual(glucoseRange?.range, expectedRange)
        XCTAssertEqual(glucoseRange?.unit, .milligramsPerDeciliter)
    }
}
